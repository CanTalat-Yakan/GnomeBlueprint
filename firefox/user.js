/* user.js
 * GnomeBlueprint Firefox preferences
 * https://github.com/CanTalat-Yakan/GnomeBlueprint
 */

// ─── Firefox GNOME Theme (Add Water) ──────────────────────────────────────────
// Enable custom stylesheets
user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);

// Set UI density to normal
user_pref("browser.uidensity", 0);

// Enable SVG context-properties
user_pref("svg.context-properties.content.enabled", true);

// Disable private window dark theme
user_pref("browser.theme.dark-private-windows", false);

// Enable rounded bottom window corners
user_pref("widget.gtk.rounded-bottom-corners.enabled", true);

// Dark toolbar
user_pref("browser.theme.toolbar-theme", 0);

// Title bar integration
user_pref("browser.tabs.inTitlebar", 1);

// ─── GNOME Theme options ──────────────────────────────────────────────────────
user_pref("gnomeTheme.hideSingleTab", true);
user_pref("gnomeTheme.normalWidthTabs", true);
user_pref("gnomeTheme.swapTabClose", false);
user_pref("gnomeTheme.bookmarksToolbarUnderTabs", false);
user_pref("gnomeTheme.tabsAsHeaderbar", false);
user_pref("gnomeTheme.tabAlignLeft", false);
user_pref("gnomeTheme.activeTabContrast", false);
user_pref("gnomeTheme.closeOnlySelectedTabs", false);
user_pref("gnomeTheme.symbolicTabIcons", false);
user_pref("gnomeTheme.allTabsButton", false);
user_pref("gnomeTheme.allTabsButtonOnOverflow", false);
user_pref("gnomeTheme.hideWebrtcIndicator", false);
user_pref("gnomeTheme.oledBlack", false);
user_pref("gnomeTheme.noThemedIcons", false);
user_pref("gnomeTheme.bookmarksOnFullscreen", false);

// ─── Startup ──────────────────────────────────────────────────────────────────
// Open previous windows and tabs
user_pref("browser.startup.page", 3);

// ─── New Tab Page ─────────────────────────────────────────────────────────────
user_pref("browser.startup.homepage", "about:home");
user_pref("browser.newtabpage.activity-stream.feeds.topsites", false);
user_pref("browser.newtabpage.activity-stream.showSearch", false);
user_pref("browser.newtabpage.activity-stream.showSponsoredCheckboxes", false);
user_pref("browser.newtabpage.activity-stream.showSponsoredTopSites", false);
user_pref("browser.newtabpage.activity-stream.showWeather", false);
// New tab background color (overridden to #000000 for Oled)
user_pref("browser.display.background_color", "#2b2b2b");

// ─── Disable AI / ML features ─────────────────────────────────────────────────
user_pref("browser.ai.control.default", "blocked");
user_pref("browser.ai.control.linkPreviewKeyPoints", "blocked");
user_pref("browser.ai.control.pdfjsAltText", "blocked");
user_pref("browser.ai.control.sidebarChatbot", "blocked");
user_pref("browser.ai.control.smartTabGroups", "blocked");
user_pref("browser.ai.control.translations", "blocked");
user_pref("browser.ml.chat.enabled", false);
user_pref("browser.ml.chat.page", false);
user_pref("browser.ml.linkPreview.enabled", false);
user_pref("browser.translations.enable", false);
user_pref("extensions.ml.enabled", false);
user_pref("pdfjs.enableAltText", false);

// ─── Disable smart tab groups ─────────────────────────────────────────────────
user_pref("browser.tabs.groups.smart.enabled", false);
user_pref("browser.tabs.groups.smart.userEnabled", false);

// ─── Toolbar & Bookmarks ─────────────────────────────────────────────────────
user_pref("browser.toolbars.bookmarks.visibility", "never");
user_pref("browser.uiCustomization.state", '{"placements":{"widget-overflow-fixed-list":[],"unified-extensions-area":[],"nav-bar":["back-button","forward-button","stop-reload-button","customizableui-special-spring1","urlbar-container","customizableui-special-spring2","downloads-button","unified-extensions-button"],"toolbar-menubar":["menubar-items"],"TabsToolbar":["tabbrowser-tabs","new-tab-button","alltabs-button"],"PersonalToolbar":["personal-bookmarks"]},"seen":[],"dirtyAreaCache":[],"currentVersion":20,"newElementCount":0}');

// ─── Sidebar ──────────────────────────────────────────────────────────────────
user_pref("sidebar.revamp", false);
user_pref("sidebar.verticalTabs", false);

// ─── Address bar shortcuts ────────────────────────────────────────────────────
user_pref("browser.urlbar.shortcuts.bookmarks", false);
user_pref("browser.urlbar.shortcuts.history", false);
user_pref("browser.urlbar.shortcuts.tabs", false);
user_pref("browser.urlbar.suggest.engines", false);

// ─── Privacy ──────────────────────────────────────────────────────────────────
user_pref("signon.rememberSignons", false);
user_pref("browser.vpn_promo.enabled", false);
user_pref("browser.contentblocking.report.vpn_sub_message.enabled", false);
user_pref("identity.fxaccounts.toolbar.enabled", false);

// ─── Profiles ─────────────────────────────────────────────────────────────────
user_pref("browser.profiles.enabled", true);
