// Enable userChrome.css / userContent.css
user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);


// --- Full built-in dark theme as the base (userChrome.css above only overrides
// the specific elements it targets - this makes every remaining native surface
// (menus, dialogs, window chrome) dark too, instead of missing pieces) ---
user_pref("extensions.activeThemeID", "firefox-compact-dark@mozilla.org");
user_pref("browser.theme.toolbar-theme", 1);
user_pref("browser.theme.content-theme", 1);

// --- Vertical (sideways) tab bar - fixed width, no hover-expand animation ---
user_pref("sidebar.revamp", false);
user_pref("sidebar.verticalTabs", false);
user_pref("sidebar.visibility", "hide-sidebar");

// --- Compact density (smaller toolbars/buttons throughout) ---
user_pref("browser.uidensity", 1);

// --- Privacy / tracking protection ---
user_pref("privacy.trackingprotection.enabled", true);
user_pref("privacy.trackingprotection.pbmode.enabled", true);
user_pref("privacy.trackingprotection.socialtracking.enabled", true);
user_pref("privacy.trackingprotection.cryptomining.enabled", true);
user_pref("privacy.trackingprotection.fingerprinting.enabled", true);
user_pref("privacy.donottrackheader.enabled", true);
user_pref("privacy.globalprivacycontrol.enabled", true);
user_pref("network.cookie.cookieBehavior", 5); // block cross-site + isolate

// --- Telemetry / data collection off ---
user_pref("toolkit.telemetry.enabled", false);
user_pref("toolkit.telemetry.unified", false);
user_pref("toolkit.telemetry.archive.enabled", false);
user_pref("datareporting.healthreport.uploadEnabled", false);
user_pref("datareporting.policy.dataSubmissionEnabled", false);
user_pref("browser.ping-centre.telemetry", false);
user_pref("app.shield.optoutstudies.enabled", false);
user_pref("browser.discovery.enabled", false);
user_pref("breakpad.reportURL", "");
user_pref("browser.tabs.crashReporting.sendReport", false);

// --- Remove new-tab sponsored bloat ---
user_pref("browser.newtabpage.activity-stream.showSponsored", false);
user_pref("browser.newtabpage.activity-stream.showSponsoredTopSites", false);
user_pref("browser.newtabpage.activity-stream.system.showSponsored", false);
user_pref("browser.newtabpage.activity-stream.discoverystream.enabled", false);

// --- Remove address-bar "Firefox Suggest" sponsored suggestions ---
user_pref("browser.urlbar.quicksuggest.enabled", false);
user_pref("browser.urlbar.suggest.quicksuggest.sponsored", false);
user_pref("browser.urlbar.suggest.quicksuggest.nonsponsored", false);

// --- Native new-tab wallpaper feature off (using a CSS-injected custom
// wallpaper via userContent.css instead - the native feature is what pushes
// the seasonal "choose a new wallpaper" promo card) ---
user_pref("browser.newtabpage.activity-stream.newtabWallpapers.enabled", false);
user_pref("browser.newtabpage.activity-stream.newtabWallpapers.v2.enabled", false);

// --- Kill Firefox's promotional "Messaging System" entirely (seasonal/CFR
// promo cards like the wallpaper one, "Firefox tips" toasts, etc.) ---
user_pref("browser.newtabpage.activity-stream.feeds.snippets", false);
user_pref("browser.newtabpage.activity-stream.asrouter.userprefs.cfr.addons", false);
user_pref("browser.newtabpage.activity-stream.asrouter.userprefs.cfr.features", false);
user_pref("browser.messaging-system.whatsNewPanel.enabled", false);

// --- Restore previous session on startup ---
user_pref("browser.startup.page", 3);

// --- Remove Top Sites shortcut tiles from the new tab page ---
user_pref("browser.newtabpage.activity-stream.feeds.topsites", false);
user_pref("browser.newtabpage.activity-stream.showTopSites", false);

// --- Native new-tab search bar (styled via userContent.css) ---
user_pref("browser.newtabpage.activity-stream.showSearch", true);

// --- Rice extras ---
user_pref("widget.gtk.rounded-bottom-corners.enabled", true);
user_pref("browser.compactmode.show", true);
user_pref("general.smoothScroll", true);
user_pref("browser.tabs.hoverPreview.enabled", true);
user_pref("browser.urlbar.trimHttps", true);
user_pref("browser.urlbar.trimURLs", true);
user_pref("browser.newtabpage.activity-stream.feeds.section.topstories", false);

// --- AI: native Firefox chatbot sidebar, Claude ---
user_pref("browser.ml.chat.enabled", true);
user_pref("browser.ml.chat.provider", "https://claude.ai/new");
user_pref("browser.ml.chat.sidebar", true);
user_pref("browser.ml.chat.shortcuts", true);
user_pref("browser.ml.chat.hideLocalhost", false);

// --- AI tab groups (native, local models) ---
user_pref("browser.ml.enable", true);
user_pref("browser.tabs.groups.enabled", true);
user_pref("browser.tabs.groups.smart.enabled", true);
user_pref("browser.tabs.groups.smart.userEnabled", true);
user_pref("browser.tabs.groups.smart.optin", true);

// --- rail: hover preview with title + thumbnail for icon-only tabs ---
user_pref("browser.tabs.hoverPreview.enabled", true);
user_pref("browser.tabs.hoverPreview.showThumbnails", true);

// --- nice-to-have behavior ---
user_pref("browser.tabs.insertAfterCurrent", true);          // new tabs open next to the current one
user_pref("browser.tabs.insertRelatedAfterCurrent", true);
user_pref("browser.tabs.unloadOnLowMemory", true);           // sleep inactive tabs when RAM is low
user_pref("media.videocontrols.picture-in-picture.video-toggle.enabled", true);
user_pref("browser.ml.linkPreview.enabled", true);           // Alt+Shift hover link preview (local AI)
user_pref("browser.ml.linkPreview.optin", true);

// --- finish: no weather widget, no bookmarks toolbar, rail tools, narrow panels ---
user_pref("browser.newtabpage.activity-stream.showWeather", false);
user_pref("browser.newtabpage.activity-stream.system.showWeather", false);
user_pref("browser.toolbars.bookmarks.visibility", "never");
user_pref("sidebar.main.tools", "aichat,syncedtabs,history,bookmarks");

// --- dock of top sites on the new tab ---
user_pref("browser.newtabpage.activity-stream.feeds.topsites", true);
user_pref("browser.newtabpage.activity-stream.showTopSites", true);
user_pref("browser.newtabpage.activity-stream.topSitesRows", 1);
user_pref("toolkit.startup.max_resumed_crashes", -1);

// --- whole-rice pass: handier behavior ---
user_pref("browser.ctrlTab.sortByRecentlyUsed", true);       // Ctrl+Tab cycles most-recent first
user_pref("browser.tabs.closeWindowWithLastTab", false);
user_pref("media.autoplay.default", 5);                      // block autoplaying video/audio
user_pref("browser.search.suggest.enabled", true);
user_pref("browser.urlbar.suggest.topsites", false);
user_pref("browser.urlbar.maxRichResults", 8);
user_pref("findbar.highlightAll", true);
user_pref("browser.download.autohideButton", true);
user_pref("browser.tabs.tabmanager.enabled", true);
user_pref("layout.css.has-selector.enabled", true);

user_pref("layout.css.devPixelsPerPx", "-1.0");
user_pref("widget.gtk.native-context-menus", false);
