import QtQuick
import "circularbuffer.js" as CB

QtObject {
    id: root

    property int capacity: 10
    readonly property int count: _count
    readonly property real maximum: _maximum
    readonly property var values: _values

    property int _count: 0
    property real _maximum: 0
    property var _values: []

    property var _buffer: CB.create(capacity)

    onCapacityChanged: {
        CB.setCapacity(_buffer, capacity);
        _sync();
    }

    function push(val: real): void {
        CB.push(_buffer, val);
        _sync();
    }

    function at(index: int): real {
        return CB.at(_buffer, index);
    }

    function clear(): void {
        CB.clear(_buffer);
        _sync();
    }

    function _sync(): void {
        _count = CB.count(_buffer);
        _maximum = CB.maximum(_buffer);
        _values = CB.values(_buffer);
    }
}
