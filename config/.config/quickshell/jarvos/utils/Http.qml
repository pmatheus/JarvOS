pragma Singleton

import Quickshell
import QtQuick

Singleton {
    id: root

    // onError and headers are both optional: most call sites pass only
    // onSuccess, and a failed request there stays silent rather than throwing.
    // onSuccess receives the raw response body — every call site parses it
    // itself.
    //
    // Qt's XMLHttpRequest accepts User-Agent but silently drops Referer, so a
    // header map is applied best-effort.
    function get(url: string, onSuccess: var, onError: var, headers: var): void {
        const xhr = new XMLHttpRequest();

        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return;
            if (xhr.status >= 200 && xhr.status < 300)
                onSuccess?.(xhr.responseText);
            else
                onError?.(xhr.status, xhr.responseText);
        };

        xhr.open("GET", url);

        if (headers)
            for (const name in headers)
                xhr.setRequestHeader(name, headers[name]);

        xhr.send();
    }
}
