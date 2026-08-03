function removeUnpairedSurrogates(value: string): string {
    let result = '';

    for (let index = 0; index < value.length; index++) {
        const code = value.charCodeAt(index);

        if (code >= 0xD800 && code <= 0xDBFF) {
            const next = value.charCodeAt(index + 1);
            if (next >= 0xDC00 && next <= 0xDFFF) {
                result += value[index] + value[index + 1];
                index++;
            }
            continue;
        }

        if (code >= 0xDC00 && code <= 0xDFFF) continue;
        result += value[index];
    }

    return result;
}

function sanitizeSearchPreview(root: Node): void {
    const walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT);
    let node = walker.nextNode() as Text | null;

    while (node) {
        node.data = removeUnpairedSurrogates(node.data);
        node = walker.nextNode() as Text | null;
    }
}

const searchResults = document.querySelector('.search-result--list');
if (searchResults) {
    // Stack may split an emoji when it truncates a search preview.
    new MutationObserver((records) => {
        for (const record of records) {
            record.addedNodes.forEach(sanitizeSearchPreview);
        }
    }).observe(searchResults, { childList: true });
}
