# Firefox with WebGL and hardware acceleration for Pop!_OS (non-NixOS)
# Uses nixGL wrapper for OpenGL support on AMD R9 290 (radeonsi driver)
{ config, pkgs, lib, inputs, ... }:

let
  nixgl = inputs.nixgl.packages.${pkgs.system};
in {
  programs.firefox = {
    enable = true;

    # Use NUR for Firefox extensions
    profiles.default = {
      id = 0;
      name = "default";
      isDefault = true;

      extensions.packages =
        with inputs.nur.legacyPackages.${pkgs.system}.repos.rycee.firefox-addons; [
          ublock-origin
          keepassxc-browser
          darkreader
          sidebery
          clearurls
        ];

      settings = {
        # === Hardware Acceleration (AMD radeonsi) ===
        "gfx.webrender.all" = true;
        "gfx.webrender.enabled" = true;
        "media.ffmpeg.vaapi.enabled" = true;
        "media.hardware-video-decoding.enabled" = true;
        "media.hardware-video-decoding.force-enabled" = true;
        "layers.acceleration.force-enabled" = true;
        "layers.offmainthreadcomposition.enabled" = true;
        "gfx.canvas.azure.accelerated" = true;
        "gfx.x11-egl.force-enabled" = true;

        # Disable software fallbacks that interfere with hardware accel
        "media.ffvpx.enabled" = false;
        "media.rdd-vpx.enabled" = false;
        "media.navigator.mediadatadecoder_vpx_enabled" = true;

        # === WebGL ===
        "webgl.disabled" = false;
        "webgl.force-enabled" = true;
        "webgl.enable-webgl2" = true;
        "webgl.enable-debug-renderer-info" = true;
        "webgl.min_capability_mode" = false;
        "webgl.disable-fail-if-major-performance-caveat" = true;
        "dom.webgpu.enabled" = true;
        "gfx.drivertweaks.disable-wmhacks" = true;

        # === Privacy ===
        "browser.newtabpage.enabled" = false;
        "browser.newtabpage.activity-stream.enabled" = false;
        "browser.newtabpage.activity-stream.feeds.section.highlights" = false;
        "browser.newtabpage.activity-stream.telemetry" = false;
        "browser.startup.homepage" = "about:blank";
        "browser.newtab.url" = "about:blank";
        "browser.newtab.preload" = false;
        "browser.newtabpage.enhanced" = false;

        # Disable telemetry
        "toolkit.telemetry.enabled" = false;
        "toolkit.telemetry.unified" = false;
        "toolkit.telemetry.server" = "data:,";
        "toolkit.telemetry.archive.enabled" = false;
        "toolkit.telemetry.coverage.opt-out" = true;
        "toolkit.coverage.opt-out" = true;
        "toolkit.coverage.endpoint.base" = "";
        "datareporting.healthreport.uploadEnabled" = false;
        "datareporting.healthreport.service.enabled" = false;
        "datareporting.policy.dataSubmissionEnabled" = false;
        "browser.ping-centre.telemetry" = false;

        # Disable experiments and studies
        "experiments.supported" = false;
        "experiments.enabled" = false;
        "experiments.manifest.uri" = "";
        "app.normandy.enabled" = false;
        "app.normandy.api_url" = "";
        "app.shield.optoutstudies.enabled" = false;

        # Disable crash reporting
        "breakpad.reportURL" = "";
        "browser.tabs.crashReporting.sendReport" = false;
        "browser.crashReports.unsubmittedCheck.autoSubmit2" = false;

        # Content blocking
        "browser.contentblocking.category" = "strict";
        "privacy.donottrackheader.enabled" = true;
        "privacy.donottrackheader.value" = 1;
        "privacy.purge_trackers.enabled" = true;

        # Disable unwanted features
        "extensions.pocket.enabled" = false;
        "extensions.shield-recipe-client.enabled" = false;
        "signon.rememberSignons" = false;
        "browser.formfill.enable" = false;
        "browser.shell.checkDefaultBrowser" = false;
        "browser.aboutConfig.showWarning" = false;
        "reader.parse-on-load.enabled" = false;
        "media.videocontrols.picture-in-picture.video-toggle.enabled" = false;

        # Form autofill
        "extensions.formautofill.addresses.enabled" = false;
        "extensions.formautofill.available" = "off";
        "extensions.formautofill.creditCards.available" = false;
        "extensions.formautofill.creditCards.enabled" = false;
        "extensions.formautofill.heuristics.enabled" = false;

        # Extension recommendations
        "extensions.htmlaboutaddons.recommendations.enabled" = false;
        "extensions.htmlaboutaddons.discover.enabled" = false;
        "extensions.getAddons.showPane" = false;
        "browser.discovery.enabled" = false;

        # URL bar
        "browser.urlbar.suggest.searches" = false;
        "browser.urlbar.shortcuts.bookmarks" = false;
        "browser.urlbar.shortcuts.history" = false;
        "browser.urlbar.shortcuts.tabs" = false;
        "browser.urlbar.showSearchSuggestionsFirst" = false;
        "browser.urlbar.speculativeConnect.enabled" = false;
        "browser.urlbar.dnsResolveSingleWordsAfterSearch" = 0;
        "browser.urlbar.suggest.quicksuggest.nonsponsored" = false;
        "browser.urlbar.suggest.quicksuggest.sponsored" = false;
        "browser.urlbar.trimURLs" = false;

        # Security
        "security.family_safety.mode" = 0;
        "security.pki.sha1_enforcement_level" = 1;
        "security.tls.enable_0rtt_data" = false;

        # Misc
        "devtools.theme" = "dark";
        "browser.sessionstore.interval" = "1800000";
        "dom.battery.enabled" = false;
        "beacon.enabled" = false;
        "browser.send_pings" = false;
        "dom.gamepad.enabled" = false;
        "browser.fixup.alternate.enabled" = false;
        "browser.disableResetPrompt" = true;
        "browser.onboarding.enabled" = false;
        "browser.newtabpage.activity-stream.asrouter.userprefs.cfr" = false;
        "browser.newtabpage.activity-stream.asrouter.userprefs.cfr.addons" =
          false;
        "browser.newtabpage.activity-stream.asrouter.userprefs.cfr.features" =
          false;
        "geo.provider.network.url" =
          "https://location.services.mozilla.com/v1/geolocate?key=%MOZILLA_API_KEY%";
        "geo.provider.use_gpsd" = false;
        "toolkit.legacyUserProfileCustomizations.stylesheets" = true;
        "services.sync.prefs.sync.browser.uiCustomization.state" = true;
      };
    };
  };

  # nixGL wrapper in ~/.local/bin takes precedence over ~/.nix-profile/bin
  # This wraps the FINAL firefox (with all home-manager config) through nixGL
  home.file.".local/bin/firefox" = {
    executable = true;
    source = pkgs.writeShellScript "firefox-nixgl" ''
      exec ${nixgl.nixGLIntel}/bin/nixGLIntel ${config.programs.firefox.finalPackage}/bin/firefox "$@"
    '';
  };

  # Keep nixGL available for wrapping other apps
  home.packages = [ nixgl.nixGLIntel ];
}
