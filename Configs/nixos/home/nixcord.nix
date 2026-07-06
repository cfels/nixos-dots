{ config, pkgs, lib, ... }:
{
  programs.nixcord = {
    enable = true;
    package = pkgs.discord;
    discord.vencord.enable = false;
    discord.equicord.enable = true;
    config = {
      themeLinks = [
        "https://catppuccin.github.io/discord/dist/catppuccin-mocha-pink.theme.css"
        "https://refact0r.github.io/system24/build/system24.css"
      ];
      plugins = {
        autoDndWhilePlaying = { enable = true; statusToSet = "dnd"; };
        betterFolders = { enable = true; enableNestedFolders = true; };
        betterGifAltText = { enable = true; };
        betterGifPicker = { enable = true; };
        betterSettings = { enable = true; organizeMenu = true; };
        betterUploadButton = { enable = true; };
        biggerStreamPreview = { enable = true; };
        callTimer = { enable = true; format = "stopwatch"; };
        clearUrls = { enable = true; };
        clientTheme = { enable = true; color = "000000"; };
        crashHandler = { enable = true; attemptToPreventCrashes = true; };
        decor = { enable = true; baseUrl = "https://decor.fieryflames.dev"; };
        disableCallIdle = { enable = true; };
        disableDeepLinks = { enable = true; };
        equicordHelper = { enable = true; };
        f8Break = { enable = true; };
        fakeNitro = {
          enable = true;
          enableEmojiBypass = true;
          enableStickerBypass = true;
          enableStreamQualityBypass = true;
          useHyperLinks = true;
        };
        fakeProfileThemes = { enable = true; nitroFirst = true; };
        fixCodeblockGap = { enable = true; };
        fixImagesQuality = { enable = true; originalImagesInChat = false; };
        fixSpotifyEmbeds = { enable = true; volume = 10.0; };
        fixYoutubeEmbeds = { enable = true; youtubeDescription = false; };
        imageZoom = { enable = true; saveZoomValues = true; zoom = 4.11; };
        memberCount = { enable = true; memberList = true; voiceActivity = true; };
        messageClickActions = {
          enable = true;
          doubleClickAction = "EDIT";
          singleClickAction = "DELETE";
          tripleClickAction = "REACT";
        };
        messageLogger = { enable = true; logDeletes = true; logEdits = true; };
        newPluginsManager = { enable = true; };
        noOnboardingDelay = { enable = true; };
        noTypingAnimation = { enable = true; };
        notificationVolume = { enable = true; notificationVolume = 58.66; };
        pictureInPicture = { enable = true; loop = true; };
        pinDms = { enable = true; };
        plainFolderIcon = { enable = true; };

        # newly enabled in your Equicord backup, added below
        previewMessage = { enable = true; };
        readAllNotificationsButton = { enable = true; };
        relationshipNotifier = { enable = true; };
        reviewDb = { enable = true; };
        serverInfo = { enable = true; sorting = "displayname"; };
        shikiCodeblocks = { enable = true; };
        showHiddenChannels = { enable = true; };
        showHiddenThings = { enable = true; };
        silentTyping = { enable = true; };
        spotifyCrack = { enable = true; noSpotifyAutoPause = true; };
        spotifyShareCommands = { enable = true; };
        translate = { enable = true; };
        typingIndicator = { enable = true; };
        typingTweaks = { enable = true; };
        unlockedAvatarZoom = { enable = true; zoomMultiplier = 4.0; };
        userVoiceShow = { enable = true; };
        viewRaw = { enable = true; };
        voiceDownload = { enable = true; };
        voiceMessages = { enable = true; };
        volumeBooster = { enable = true; multiplier = 2.0; };
        whoReacted = { enable = true; };
        youtubeAdblock = { enable = true; };
      };
    };
  };
}

