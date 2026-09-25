{ ... }:
{
  programs.nixcord.config.plugins = {
    anonymiseFileNames = {
      randomisedLength = 16;
    };
    autoDndWhilePlaying.enable = true;
    betterAudioPlayer = {
      oscilloscope = false;
      oscilloscopeColor = "216, 216, 246";
      spectrographColor = "177, 143, 207";
    };
    betterFolders.enable = true;
    betterGifAltText.enable = true;
    betterGifPicker.enable = true;
    betterImageEditor.enable = true;
    betterSettings.enable = true;
    betterUploadButton.enable = true;
    biggerStreamPreview.enable = true;
    blurNsfw.enable = true;
    bypassStatus.enable = true;
    callTimer.enable = true;
    clearUrls.enable = true;
    clientTheme = {
      enable = true;
      color = "000000";
    };
    collapsibleUi.enable = true;
    concatenatedComponentExtractor.enable = true;
    concatenatedModules.enable = true;
    crashHandler.enable = true;
    cursorBuddy = {
      enable = true;
      fps = 10;
      size = 64;
    };
    decor = {
      enable = true;
      agreedToGuidelines = true;
    };
    disableCallIdle.enable = true;
    disableDeepLinks.enable = true;
    downloadAllAttachments.enable = true;
    equibopStreamFixes = {
      enable = true;
      minBitrate = 20000;
    };
    equicordHelper.enable = true;
    f8Break.enable = true;
    fakeNitro.enable = true;
    fakeProfileThemes = {
      nitroFirst = false;
    };
    fastDeleteChannels.enable = true;
    favouriteAnything.enable = true;
    fixCodeblockGap.enable = true;
    fixImagesQuality.enable = true;
    fixSpotifyEmbeds.enable = true;
    fixYoutubeEmbeds.enable = true;
    gameActivityToggle = {
      oldIcon = true;
    };
    ignoreActivities = {
      ignorePlaying = true;
      ignoreStreaming = true;
      ignoreListening = true;
      ignoreWatching = true;
      ignoreCompeting = true;
    };
    imageFilename.enable = true;
    imageZoom = {
      enable = true;
      size = 149.52380952380952;
      zoom = 3.3000000000000003;
      square = true;
    };
    markdownTables.enable = true;
    memberCount = {
      enable = true;
      toolTip = false;
    };
    messageClickActions = {
      enable = true;
      enableDoubleClickToEdit = false;
      requireModifier = true;
    };
    messageLogger = {
      enable = true;
      ignoreBots = false;
    };
    musicRichPresence = {
      username = "";
      apiKey = "";
      instanceBaseUrl = "";
      instanceApiBaseUrl = "";
    };
    newGuildSettings = {
      enable = true;
      messages = 2;
    };
    noMosaic.enable = true;
    noNitroUpsell.enable = true;
    noOnboardingDelay.enable = true;
    noPendingCount.enable = true;
    noProfileThemes.enable = true;
    notificationVolume = {
      enable = true;
      notificationVolume = 58.664259927797836;
    };
    noTrack.enable = true;
    noTypingAnimation.enable = true;
    pictureInPicture.enable = true;
    pinDms.enable = true;
    plainFolderIcon.enable = true;
    platformIndicators.enable = true;
    previewMessage.enable = true;
    questify = {
      enable = true;
      disableSponsoredBanner = true;
      disableAccountPanelQuestProgress = true;
      disableOrbsAndQuestsBadges = true;
      disableQuestsEverything = true;
      questButtonBadgeCount = 6;
      acknowledgedNotices = {
        quest-ban-warning-2026-08-07 = true;
        quest-ban-warning-2026-08-26 = true;
      };
    };
    randomVoice = {
      keybind = [ "Control" "Shift" "R" ];
    };
    readAllNotificationsButton.enable = true;
    relationshipNotifier.enable = true;
    revealAllSpoilers.enable = true;
    reverseImageSearch.enable = true;
    reviewDb.enable = true;
    serverInfo.enable = true;
    settings.enable = true;
    shikiCodeblocks = {
      enable = true;
      theme = "https://cdn.jsdelivr.net/gh/shikijs/textmate-grammars-themes@bc5436518111d87ea58eb56d97b3f9bec30e6b83/packages/tm-themes/themes/dark-plus.json";
    };
    showHiddenChannels.enable = true;
    showHiddenThings.enable = true;
    silentTyping.enable = false;
    sortFriends = {
      enable = true;
      showDates = true;
    };
    spotifyCrack = {
      enable = true;
      noSpotifyAutoPause = false;
    };
    spotifyShareCommands.enable = true;
    streaks.enable = true;
    streamerModeOnStream.enable = true;
    supportHelper.enable = true;
    translate = {
      enable = true;
      receivedOutput = "pl";
      sentOutput = "pl";
    };
    typingIndicator.enable = true;
    typingTweaks.enable = true;
    unlockedAvatarZoom.enable = true;
    userPfp.enable = true;
    userVoiceShow.enable = true;
    usrbg.enable = true;
    viewIcons.enable = true;
    viewRaw.enable = true;
    voiceDownload.enable = true;
    voiceMessages = {
      enable = true;
      echoCancellation = false;
      noiseSuppression = false;
    };
    voiceMessageTranscriber = {
      enable = true;
      selectedModel = "Xenova/whisper-base";
      quantized = false;
    };
    voiceStats.enable = true;
    volumeBooster.enable = true;
    webContextMenus = {
      enable = true;
      addBack = true;
    };
    webKeybinds = {
      enable = true;
      overrideCommonKeybinds = true;
    };
    webScreenShareFixes.enable = true;
    whoReacted.enable = true;
    whosWatching.enable = true;
    youtubeAdblock.enable = true;
    zipPreview.enable = true;
  };
  programs.nixcord.extraConfig.plugins = {
    autoDndWhilePlaying = {
      excludeInvisible = false;
    };
    betterFolders = {
      enableNestedFolders = true;
      nestedFolders = { };
    };
    BetterGifLoad = {
      gifQuality = 1;
    };
    betterGifPicker = {
      keepOpen = false;
    };
    customCommands = {
      clyde = true;
    };
    equicordHelper = {
      noOnboarding = false;
    };
    FavoriteGifSearch = {
      searchOption = "hostandpath";
    };
    musicRichPresence = {
      showLastFmLogo = true;
    };
    translate = {
      showChatBarButton = true;
    };
    whoReacted = {
      avatarClick = false;
    };
  };
}
