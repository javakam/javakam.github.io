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

type VisualTheme = 'stack' | 'ocean' | 'forest' | 'graphite';

const VISUAL_THEME_STORAGE_KEY = 'StackVisualTheme';
const visualThemes: Array<{ value: VisualTheme; label: string }> = [
    { value: 'stack', label: 'Stack 原版' },
    { value: 'ocean', label: '海风蓝' },
    { value: 'forest', label: '松石绿' },
    { value: 'graphite', label: '极简石墨' },
];

function isVisualTheme(value: string | null | undefined): value is VisualTheme {
    return visualThemes.some((theme) => theme.value === value);
}

function getSavedVisualTheme(): VisualTheme {
    const activeTheme = document.documentElement.dataset.visualTheme;
    if (isVisualTheme(activeTheme)) return activeTheme;

    try {
        const savedTheme = localStorage.getItem(VISUAL_THEME_STORAGE_KEY);
        if (isVisualTheme(savedTheme)) return savedTheme;
    } catch (error) {
        // Storage can be unavailable in restricted browser contexts.
    }

    return 'stack';
}

function applyVisualTheme(theme: VisualTheme, persist = true): void {
    if (theme === 'stack') {
        delete document.documentElement.dataset.visualTheme;
    } else {
        document.documentElement.dataset.visualTheme = theme;
    }

    if (!persist) return;

    try {
        if (theme === 'stack') {
            localStorage.removeItem(VISUAL_THEME_STORAGE_KEY);
        } else {
            localStorage.setItem(VISUAL_THEME_STORAGE_KEY, theme);
        }
    } catch (error) {
        // The selected theme still applies for the current page.
    }
}

function createVisualThemeSwitcher(activeTheme: VisualTheme): void {
    const bottomMenu = document.querySelector<HTMLOListElement>('#main-menu .menu-bottom-section > .menu');
    if (!bottomMenu || document.getElementById('visual-theme-switcher')) return;

    const item = document.createElement('li');
    item.id = 'visual-theme-switcher';

    const palette = document.createElement('span');
    palette.className = 'theme-switcher__palette';
    palette.setAttribute('aria-hidden', 'true');

    for (const theme of visualThemes) {
        const swatch = document.createElement('i');
        swatch.className = `theme-switcher__swatch theme-switcher__swatch--${theme.value}`;
        palette.appendChild(swatch);
    }

    const select = document.createElement('select');
    select.id = 'visual-theme-select';
    select.setAttribute('aria-label', '主题样式');
    select.title = '主题样式';

    for (const theme of visualThemes) {
        const option = document.createElement('option');
        option.value = theme.value;
        option.textContent = theme.label;
        select.appendChild(option);
    }

    select.value = activeTheme;
    select.addEventListener('change', () => {
        if (isVisualTheme(select.value)) applyVisualTheme(select.value);
    });

    item.append(palette, select);

    const darkModeToggle = document.getElementById('dark-mode-toggle');
    if (darkModeToggle?.parentElement === bottomMenu) {
        bottomMenu.insertBefore(item, darkModeToggle);
    } else {
        bottomMenu.appendChild(item);
    }
}

const activeVisualTheme = getSavedVisualTheme();
applyVisualTheme(activeVisualTheme, false);
createVisualThemeSwitcher(activeVisualTheme);

window.addEventListener('storage', (event) => {
    if (event.key !== VISUAL_THEME_STORAGE_KEY) return;

    const theme = isVisualTheme(event.newValue) ? event.newValue : 'stack';
    applyVisualTheme(theme, false);

    const select = document.querySelector<HTMLSelectElement>('#visual-theme-select');
    if (select) select.value = theme;
});
