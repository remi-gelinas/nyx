{
  flake.modules.darwin.system = {
    system.defaults = {
      LaunchServices.LSQuarantine = false;

      finder = {
        CreateDesktop = false;
        AppleShowAllExtensions = true;
        FXEnableExtensionChangeWarning = false;
        FXPreferredViewStyle = "icnv";
        QuitMenuItem = true;
        ShowPathbar = true;
      };

      NSGlobalDomain = {
        NSAutomaticWindowAnimationsEnabled = false;
        NSDocumentSaveNewDocumentsToCloud = false;
        NSAutomaticCapitalizationEnabled = false;
        NSAutomaticSpellingCorrectionEnabled = false;
        NSAutomaticPeriodSubstitutionEnabled = false;
        NSAutomaticDashSubstitutionEnabled = false;
        NSAutomaticQuoteSubstitutionEnabled = false;
      };

      CustomSystemPreferences."NSGlobalDomain"."NSWindowShouldDragOnGesture" = "YES";
    };

    security.pam.services.sudo_local.touchIdAuth = true;
  };
}
