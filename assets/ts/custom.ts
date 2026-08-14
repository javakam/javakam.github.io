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
const visualThemes: Array<{ value: VisualTheme; label: string; colors: string[] }> = [
    { value: 'stack', label: 'Stack 原版', colors: ['#f5f5fa', '#34495e', '#ffffff', '#707070'] },
    { value: 'ocean', label: '海风蓝', colors: ['#eef3f8', '#2563eb', '#ffffff', '#536176'] },
    { value: 'forest', label: '松石绿', colors: ['#edf4f1', '#147d64', '#ffffff', '#586d65'] },
    { value: 'graphite', label: '极简石墨', colors: ['#f1f3f5', '#24292f', '#ffffff', '#6e7781'] },
];

let visualThemeToggle: HTMLButtonElement | null = null;
let visualThemePanel: HTMLDivElement | null = null;

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

    if (persist) {
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

    updateVisualThemeControls(theme);
}

function createThemePreview(colors: string[], className: string): HTMLSpanElement {
    const preview = document.createElement('span');
    preview.className = className;
    preview.setAttribute('aria-hidden', 'true');

    for (const color of colors) {
        const swatch = document.createElement('i');
        swatch.style.backgroundColor = color;
        preview.appendChild(swatch);
    }

    return preview;
}

function updateVisualThemeControls(theme: VisualTheme): void {
    const activeTheme = visualThemes.find((item) => item.value === theme) ?? visualThemes[0];

    if (visualThemeToggle) {
        const preview = visualThemeToggle.querySelector<HTMLElement>('.theme-switcher__preview');
        preview?.querySelectorAll<HTMLElement>('i').forEach((swatch, index) => {
            swatch.style.backgroundColor = activeTheme.colors[index];
        });
        visualThemeToggle.setAttribute('aria-label', `选择主题，当前为${activeTheme.label}`);
        visualThemeToggle.title = `主题：${activeTheme.label}`;
    }

    visualThemePanel?.querySelectorAll<HTMLButtonElement>('[data-theme-value]').forEach((option) => {
        const selected = option.dataset.themeValue === theme;
        option.classList.toggle('is-selected', selected);
        option.setAttribute('aria-checked', String(selected));
        option.tabIndex = selected ? 0 : -1;
    });
}

function positionVisualThemePanel(): void {
    if (!visualThemeToggle || !visualThemePanel || visualThemePanel.hidden) return;

    const viewportGap = 12;
    for (const property of ['left', 'right', 'top', 'bottom']) {
        visualThemePanel.style.removeProperty(property);
    }

    if (window.innerWidth < 768) {
        visualThemePanel.style.left = `${viewportGap}px`;
        visualThemePanel.style.right = `${viewportGap}px`;
        visualThemePanel.style.bottom = `${viewportGap}px`;
        return;
    }

    const toggleRect = visualThemeToggle.getBoundingClientRect();
    const panelRect = visualThemePanel.getBoundingClientRect();
    const left = Math.min(
        Math.max(viewportGap, toggleRect.left),
        window.innerWidth - panelRect.width - viewportGap,
    );
    const preferredTop = toggleRect.top - panelRect.height - 8;
    const top = preferredTop >= viewportGap
        ? preferredTop
        : Math.min(toggleRect.bottom + 8, window.innerHeight - panelRect.height - viewportGap);

    visualThemePanel.style.left = `${Math.round(left)}px`;
    visualThemePanel.style.top = `${Math.round(Math.max(viewportGap, top))}px`;
}

function closeVisualThemePanel(restoreFocus = false): void {
    if (!visualThemeToggle || !visualThemePanel || visualThemePanel.hidden) return;

    visualThemePanel.hidden = true;
    visualThemeToggle.setAttribute('aria-expanded', 'false');
    if (restoreFocus) visualThemeToggle.focus();
}

function openVisualThemePanel(): void {
    if (!visualThemeToggle || !visualThemePanel) return;

    visualThemePanel.hidden = false;
    visualThemeToggle.setAttribute('aria-expanded', 'true');
    positionVisualThemePanel();

    const selectedOption = visualThemePanel.querySelector<HTMLButtonElement>('[aria-checked="true"]');
    requestAnimationFrame(() => selectedOption?.focus());
}

function createVisualThemeSwitcher(activeTheme: VisualTheme): void {
    const bottomMenu = document.querySelector<HTMLOListElement>('#main-menu .menu-bottom-section > .menu');
    if (!bottomMenu || document.getElementById('visual-theme-switcher')) return;

    const item = document.createElement('li');
    item.id = 'visual-theme-switcher';

    visualThemeToggle = document.createElement('button');
    visualThemeToggle.id = 'visual-theme-toggle';
    visualThemeToggle.type = 'button';
    visualThemeToggle.setAttribute('aria-haspopup', 'menu');
    visualThemeToggle.setAttribute('aria-expanded', 'false');
    visualThemeToggle.setAttribute('aria-controls', 'visual-theme-panel');

    const activeThemeConfig = visualThemes.find((theme) => theme.value === activeTheme) ?? visualThemes[0];
    visualThemeToggle.appendChild(createThemePreview(activeThemeConfig.colors, 'theme-switcher__preview'));

    const toggleLabel = document.createElement('span');
    toggleLabel.className = 'theme-switcher__label';
    toggleLabel.textContent = '主题';
    visualThemeToggle.appendChild(toggleLabel);

    visualThemePanel = document.createElement('div');
    visualThemePanel.id = 'visual-theme-panel';
    visualThemePanel.className = 'theme-picker';
    visualThemePanel.hidden = true;
    visualThemePanel.setAttribute('role', 'menu');
    visualThemePanel.setAttribute('aria-label', '主题样式');

    const panelTitle = document.createElement('div');
    panelTitle.className = 'theme-picker__title';
    panelTitle.textContent = '主题样式';
    visualThemePanel.appendChild(panelTitle);

    const optionList = document.createElement('div');
    optionList.className = 'theme-picker__options';

    for (const theme of visualThemes) {
        const option = document.createElement('button');
        option.type = 'button';
        option.className = 'theme-picker__option';
        option.dataset.themeValue = theme.value;
        option.setAttribute('role', 'menuitemradio');
        option.setAttribute('aria-checked', String(theme.value === activeTheme));
        option.tabIndex = theme.value === activeTheme ? 0 : -1;

        option.appendChild(createThemePreview(theme.colors, 'theme-picker__preview'));

        const label = document.createElement('span');
        label.className = 'theme-picker__label';
        label.textContent = theme.label;
        option.appendChild(label);

        const check = document.createElement('span');
        check.className = 'theme-picker__check';
        check.setAttribute('aria-hidden', 'true');
        check.textContent = '✓';
        option.appendChild(check);

        option.addEventListener('click', () => {
            applyVisualTheme(theme.value);
            closeVisualThemePanel(true);
        });
        optionList.appendChild(option);
    }

    visualThemePanel.appendChild(optionList);
    document.body.appendChild(visualThemePanel);

    visualThemeToggle.addEventListener('click', () => {
        if (visualThemePanel?.hidden) {
            openVisualThemePanel();
        } else {
            closeVisualThemePanel();
        }
    });

    visualThemePanel.addEventListener('keydown', (event) => {
        const options = Array.from(
            visualThemePanel?.querySelectorAll<HTMLButtonElement>('[data-theme-value]') ?? [],
        );
        const currentIndex = options.indexOf(document.activeElement as HTMLButtonElement);
        let nextIndex: number | null = null;

        if (event.key === 'Escape') {
            event.preventDefault();
            closeVisualThemePanel(true);
            return;
        }
        if (event.key === 'ArrowDown') nextIndex = (currentIndex + 1) % options.length;
        if (event.key === 'ArrowUp') nextIndex = (currentIndex - 1 + options.length) % options.length;
        if (event.key === 'Home') nextIndex = 0;
        if (event.key === 'End') nextIndex = options.length - 1;

        if (nextIndex !== null) {
            event.preventDefault();
            options[nextIndex]?.focus();
        }
    });
    visualThemePanel.addEventListener('focusout', (event) => {
        const nextTarget = event.relatedTarget as Node | null;
        if (nextTarget && (
            visualThemePanel?.contains(nextTarget)
            || visualThemeToggle?.contains(nextTarget)
        )) return;

        closeVisualThemePanel();
    });

    item.appendChild(visualThemeToggle);

    const darkModeToggle = document.getElementById('dark-mode-toggle');
    if (darkModeToggle?.parentElement === bottomMenu) {
        bottomMenu.insertBefore(item, darkModeToggle);
    } else {
        bottomMenu.appendChild(item);
    }

    document.addEventListener('pointerdown', (event) => {
        const target = event.target as Node;
        if (visualThemePanel?.contains(target) || visualThemeToggle?.contains(target)) return;
        closeVisualThemePanel();
    });
    document.getElementById('toggle-menu')?.addEventListener('click', () => closeVisualThemePanel());
    window.addEventListener('resize', positionVisualThemePanel);
    window.addEventListener('scroll', positionVisualThemePanel, { passive: true });

    updateVisualThemeControls(activeTheme);
}

const activeVisualTheme = getSavedVisualTheme();
applyVisualTheme(activeVisualTheme, false);
createVisualThemeSwitcher(activeVisualTheme);

window.addEventListener('storage', (event) => {
    if (event.key !== VISUAL_THEME_STORAGE_KEY) return;

    const theme = isVisualTheme(event.newValue) ? event.newValue : 'stack';
    applyVisualTheme(theme, false);
});
