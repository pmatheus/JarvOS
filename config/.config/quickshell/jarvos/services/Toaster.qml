pragma Singleton

import QtQuick

import qs.components.misc

import "../utils/toast.js" as Queue

// Toast queue singleton, ported from caelestia's C++ Toaster. Call
// Toaster.toast(title, message, icon, type?, timeout?) — the type defaults
// to Info and the timeout to 5000ms; normalization of empty icons and
// non-positive timeouts happens in utils/toast.js. The list is reassigned
// rather than mutated in place so every consumer binding re-evaluates.
QtObject {
    id: root

    property var toasts: []

    property Component toastComp: Component {
        Toast {
            id: toast

            onFinishedClose: {
                Queue.remove(root.toasts, toast);
                root.toasts = root.toasts.slice();
                toast.destroy();
            }
        }
    }

    function toast(title, message = "", icon = "", type = Toast.Info, timeout = 5000): void {
        const spec = Queue.create(title ?? "", message ?? "", icon ?? "", type ?? Toast.Info, timeout ?? 5000);
        const t = root.toastComp.createObject(root, {
            "title": spec.title,
            "message": spec.message,
            "icon": spec.icon,
            "type": spec.type,
            "timeout": spec.timeout
        });
        Queue.push(root.toasts, t);
        root.toasts = root.toasts.slice();
    }
}
