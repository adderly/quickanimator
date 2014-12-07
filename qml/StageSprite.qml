import QtQuick 2.1

Item {
    id: sprite

    x: parent.width / 2
    y: parent.height / 2

    property bool selected: false
    property Item focusIndicator: null

    property real anchorX: childrenRect.width / 2
    property real anchorY: childrenRect.height / 2
    property alias transRotation: tRotation.angle
    property alias transScaleX: tScale.xScale
    property alias transScaleY: tScale.yScale

    transform: [
        Scale { id: tScale; xScale: 1; yScale: 1; origin.x: anchorX; origin.y: anchorY },
        Rotation { id: tRotation; angle: 0; origin.x: anchorX; origin.y: anchorY }
    ]

    property QtObject model: parent 
    property var keyframes: new Array
    property int keyframeIndex: 0

    property real spriteTime: 0

    property var _fromKeyframe
    property var _toKeyframe
    property bool _invalidCache: true

    objectName: "unknown sprite"

    function setTime(time)
    {
        _updateCurrentKeyframes(time);
        spriteTime = time;
        if (selected && model.inLiveDrag)
            _interpolateWithRecordOptionFilter(spriteTime)
        else
            _interpolate(spriteTime)
    }

    function getKeyframe(time)
    {
        var intTime = Math.floor(time);
        return (intTime >= _fromKeyframe.time && intTime < _toKeyframe.time)
                ? getCurrentKeyframe() : _getKeyframeBinarySearch(intTime);
    }

    function getCurrentKeyframe()
    {
        _updateCurrentKeyframes(spriteTime);
        return _fromKeyframe;
    }

    function addKeyframe(keyframe)
    {
        keyframe.volatileIndex = keyframes.length === 0 ? 0 : getKeyframe(keyframe.time).volatileIndex + 1;
        keyframes.splice(keyframe.volatileIndex, 0, keyframe);
        model.callbackKeyframeAdded(sprite, keyframe);
        _invalidCache = true;
    }

    function removeKeyframe(keyframe)
    {
        keyframes.splice(keyframes.indexOf(keyframe), 1);
        _invalidCache = true;
        setTime(spriteTime);
    }

    function createKeyframe(time)
    {
        return {
            time:time,
            sprite:sprite,
            name:objectName + "," + time,
            x:sprite.x,
            y:sprite.y,
            z:sprite.z,
            anchorX: tScale.origin.x,
            anchorY: tScale.origin.y,
            width:sprite.width,
            height:sprite.height,
            transRotation:transRotation,
            transScaleX:transScaleX,
            transScaleY:transScaleY,
            opacity:sprite.opacity,
            visible: sprite.visible
        };
    }

    function updateKeyframe(time, props, flags)
    {
        var newKeyframeCreated = false;
        var intTime = Math.floor(time);
        var keyframe = getKeyframe(intTime);

        if (!keyframe || keyframe.time !== intTime) {
            keyframe = createKeyframe(intTime);
            newKeyframeCreated = true;
        }

        if (time === spriteTime) {
            for (var key in props)
                sprite[key] = props[key];
        }

        if (flags.propagate) {
            // Iterate through subsequent keyframes and update props
            // that has the same value set as keyframe.
            for (var i = keyframe.volatileIndex + 1; i < keyframes.length; ++i) {
                var kf = keyframes[i];
                for (key in props) {
                    var noPropSet = true;
                    if (kf[key] === keyframe[key]) {
                        kf[key] = props[key];
                        noPropSet = false;
                    }
                }
                if (noPropSet)
                    break;
            }
        }

        for (key in props)
           keyframe[key] = props[key];

        if (newKeyframeCreated)
            addKeyframe(keyframe);

        return newKeyframeCreated;
    }

    function _createKeyframeRelativeToParent(time, keyframeParent)
    {
        // Create a keyframe from the current sprite geometry
        // described relative to keyframeParent rather than actual parent:
        var currentKeyframe = getCurrentKeyframe();

        if (keyframeParent === parent)
            return _fromKeyframe.reparentKeyframe ? _fromKeyframe.reparentKeyframe : _fromKeyframe;

        var commonParent = myApp.stage.sprites;

        // Get current sprite geometry in commonParent coordinates:
        var hotspotX = (width / 2);
        var hotspotY = (height / 2);
        var gHotspot = mapToItem(commonParent, hotspotX, hotspotY);
        var gRefPoint = mapToItem(commonParent, hotspotX + 1, hotspotY);
        var dx = gRefPoint.x - gHotspot.x;
        var dy = gRefPoint.y - gHotspot.y;
        var gRotation = (Math.atan2(dy, dx) * 180 / Math.PI);
        var gScale = Math.sqrt((dx * dx) + (dy * dy));

        // Get keyframeParent geometry in commonParent coordinates:
        var itemHotspotX = (keyframeParent.width / 2);
        var itemHotspotY = (keyframeParent.height / 2);
        var gItemHotspot = keyframeParent.mapToItem(commonParent, itemHotspotX, itemHotspotY);
        var gItemRefPoint = keyframeParent.mapToItem(commonParent, itemHotspotX + 1, itemHotspotY);
        var itemDx = gItemRefPoint.x - gItemHotspot.x;
        var itemDy = gItemRefPoint.y - gItemHotspot.y;
        var gItemRotation = (Math.atan2(itemDy, itemDx) * 180 / Math.PI);
        var gItemScale = Math.sqrt((itemDx * itemDx) + (itemDy * itemDy));

        // Translate sprite to keyframeParent, preserving rotation and scale:
        var translatedHotspot = keyframeParent.mapFromItem(commonParent, gHotspot.x, gHotspot.y);
        var translatedKeyframe = createKeyframe(time);
        translatedKeyframe.parent = keyframeParent;
        translatedKeyframe.x = translatedHotspot.x - (sprite.width / 2);
        translatedKeyframe.y = translatedHotspot.y - (sprite.height / 2);
        translatedKeyframe.transRotation = gRotation - gItemRotation;
        translatedKeyframe.transScale = gScale / gItemScale;

        return translatedKeyframe;
    }

    function synchReparentKeyframe(changedSprite)
    {
        // Since changedSprite has changed, all descandant of it has changed as well (relative
        // to Stage, not parent). As such, we need to synch their keyframes left-side, so that
        // they end up with the geometry they now got upon reparenting.
        _updateCurrentKeyframes(spriteTime);
        if (!_fromKeyframe.reparentKeyframe || _fromKeyframe.time !== changedSprite._fromKeyframe.time)
            return;

        var p = getKeyframeParent(_fromKeyframe.volatileIndex - 1);
        var translated = _createKeyframeRelativeToParent(_fromKeyframe.time, p);
        _fromKeyframe.x = translated.x;
        _fromKeyframe.y = translated.y;
        _fromKeyframe.transScale = translated.transScale;
        _fromKeyframe.transRotation = translated.transRotation;
    }

    function _interpolate(time)
    {
        var keyframe = _fromKeyframe.reparentKeyframe ? _fromKeyframe.reparentKeyframe : _fromKeyframe;
        visible = keyframe.visible;
        if (!visible)
            return;

        if (_toKeyframe.time === keyframe.time) {
            x = keyframe.x;
            y = keyframe.y;
            z = keyframe.z;
            anchorX = keyframe.anchorX;
            anchorY = keyframe.anchorY;
            transScaleX = keyframe.transScaleX;
            transScaleY = keyframe.transScaleY;
            transRotation = keyframe.transRotation;
            opacity = keyframe.opacity;
        } else {
            var reparentKeyframeMs = keyframe.time * model.playbackMpf
            var advanceMs = (spriteTime * model.playbackMpf) - reparentKeyframeMs;
            x = _interpolated(keyframe.x, _toKeyframe.x, advanceMs, "linear");
            y = _interpolated(keyframe.y, _toKeyframe.y, advanceMs, "linear");
            z = _interpolated(keyframe.z, _toKeyframe.z, advanceMs, "linear");
            anchorX = _interpolated(keyframe.anchorX, _toKeyframe.anchorX, advanceMs, "linear");
            anchorY = _interpolated(keyframe.anchorY, _toKeyframe.anchorY, advanceMs, "linear");
            transScaleX = _interpolated(keyframe.transScaleX, _toKeyframe.transScaleX, advanceMs, "linear");
            transScaleY = _interpolated(keyframe.transScaleY, _toKeyframe.transScaleY, advanceMs, "linear");
            transRotation = _interpolated(keyframe.transRotation, _toKeyframe.transRotation, advanceMs, "linear");
            opacity = _interpolated(keyframe.opacity, _toKeyframe.opacity, advanceMs, "linear");
        }
    }

    function _interpolateWithRecordOptionFilter(time)
    {
        var keyframe = _fromKeyframe.reparentKeyframe ? _fromKeyframe.reparentKeyframe : _fromKeyframe;
        visible = keyframe.visible;
        if (!visible)
            return;

        if (_toKeyframe.time === keyframe.time) {
            if (!model.recordsPositionX)
                x = keyframe.x;
            if (!model.recordsPositionY)
                y = keyframe.y;
            z = keyframe.z;
            if (!model.recordsAnchorX)
                anchorX = keyframe.anchorX;
            if (!model.recordsAnchorY)
                anchorY = keyframe.anchorY;
            if (!model.recordsScale) {
                transScaleX = keyframe.transScaleX;
                transScaleY = keyframe.transScaleY;
            }
            if (!model.recordsRotation)
                transRotation = keyframe.transRotation;
            if (!model.recordsOpacity)
                opacity = keyframe.opacity;
        } else {
            var reparentKeyframeMs = keyframe.time * model.playbackMpf
            var advanceMs = (spriteTime * model.playbackMpf) - reparentKeyframeMs;
            if (!model.recordsPositionX)
                x = _interpolated(keyframe.x, _toKeyframe.x, advanceMs, "linear");
            if (!model.recordsPositionY)
                y = _interpolated(keyframe.y, _toKeyframe.y, advanceMs, "linear");
            z = _interpolated(keyframe.z, _toKeyframe.z, advanceMs, "linear");
            if (!model.recordsAnchorX)
                anchorX = _interpolated(keyframe.anchorX, _toKeyframe.anchorX, advanceMs, "linear");
            if (!model.recordsAnchorY)
                anchorY = _interpolated(keyframe.anchorY, _toKeyframe.anchorY, advanceMs, "linear");
            if (!model.recordsScale) {
                transScaleX = _interpolated(keyframe.transScaleX, _toKeyframe.transScaleX, advanceMs, "linear");
                transScaleY = _interpolated(keyframe.transScaleY, _toKeyframe.transScaleY, advanceMs, "linear");
            }
            if (!model.recordsRotation)
                transRotation = _interpolated(keyframe.transRotation, _toKeyframe.transRotation, advanceMs, "linear");
            if (!model.recordsOpacity)
                opacity = _interpolated(keyframe.opacity, _toKeyframe.opacity, advanceMs, "linear");
        }
    }

    function _interpolated(from, to, advanceMs, curve)
    {
        // Ignore curve for now:
        var fromKeyframeMs = _fromKeyframe.time * model.playbackMpf
        var timeDiff = (_toKeyframe.time * model.playbackMpf) - fromKeyframeMs;
        return from + (((to - from) / timeDiff) * advanceMs);
    }

    function _updateCurrentKeyframes(time)
    {
        var intTime = Math.floor(time);
        _invalidCache = _invalidCache || !_fromKeyframe || !_toKeyframe || intTime < _fromKeyframe.time || intTime >= _toKeyframe.time;
        if (!_invalidCache)
            return;

        _invalidCache = false;
        _fromKeyframe = _getKeyframeBinarySearch(intTime);
        keyframeIndex = _fromKeyframe.volatileIndex;
        if (keyframeIndex === keyframes.length - 1) {
            _toKeyframe = _fromKeyframe;
        } else {
            _toKeyframe = keyframes[keyframeIndex + 1];
            _toKeyframe.volatileIndex = keyframeIndex + 1;
        }

        var p = getKeyframeParent(_fromKeyframe.volatileIndex);
        if (p.parent === sprite) {
            // Sprites cannot be children of each other
            p.parent = null;
        }
        parent = p;
    }

    function getKeyframeParent(keyframeIndex)
    {
        for (var i = keyframeIndex; i >= 0; --i) {
            var reparentKeyframe = keyframes[i].reparentKeyframe;
            if (reparentKeyframe) {
                var p = reparentKeyframe.parent;
                break;
            }
        }
        // fixme: find root parent by searching
        // up, instead of relying on myApp.stage.sprites
        return p ? p : myApp.stage.sprites;
    }

//    onParentChanged: {
//        print("------");
//        if (parent)
//            print(objectName, "is child of", parent.objectName);
//        else
//            print(objectName, "is parented out!");
//        console.trace();
//    }

    function _getKeyframeBinarySearch(time)
    {
        // Binary search keyframes:
        var low = 0, high = keyframes.length - 1;
        var t, i;

        while (low <= high) {
            i = Math.floor((low + high) / 2);
            t = keyframes[i].time;
            if (time < t) {
                high = i - 1;
                continue;
            }
            if (i === high || time < keyframes[i + 1].time)
                break;
            low = i + 1
        }
        var keyframe = keyframes[i];
        keyframe.volatileIndex = i;
        return keyframe;
    }

    function changeParent(newParent)
    {
        if (parent === newParent)
            return;

        var currentKeyframe = getCurrentKeyframe();
        if (getKeyframeParent(currentKeyframe.volatileIndex - 1) === newParent)
            currentKeyframe.reparentKeyframe = null;
        else
            currentKeyframe.reparentKeyframe = _createKeyframeRelativeToParent(currentKeyframe.time, newParent);

        // Reparent sprite:
        parent = null;
        parent = newParent

        if (!myApp.model.inLiveDrag)
            _interpolate(spriteTime);
    }

}
