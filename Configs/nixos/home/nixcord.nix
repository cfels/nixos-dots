{ config, pkgs, lib, ... }:

{
  #imports = [ ./nixcord-secrets.nix ];

  programs.nixcord = {
    enable = true;
    package = pkgs.discord;
    discord.vencord.enable = false;
    discord.equicord.enable = true;
    config = {
      themeLinks = [
        "https://catppuccin.github.io/discord/dist/catppuccin-mocha-pink.theme.css"
      ];
      enabledThemeLinks = [
        "https://catppuccin.github.io/discord/dist/catppuccin-mocha-pink.theme.css"
      ];
      plugins = {
        autoDndWhilePlaying = { enable = true; statusToSet = "dnd"; };
        betterFolders = { enable = true; };
        betterGifAltText = { enable = true; };
        betterGifPicker = { enable = true; };
        betterSettings = { enable = true; organizeMenu = true; };
        betterUploadButton = { enable = true; };
        biggerStreamPreview = { enable = true; };
        callTimer = { enable = true; format = "stopwatch"; };
        clearUrls = { enable = true; };
        clientTheme = { enable = true; color = "000000"; };
        crashHandler = { enable = true; attemptToPreventCrashes = true; };
        customTimestamps = {
          formats = {
            enable = false;
          };
        };
        decor = { enable = true; baseUrl = "https://decor.fieryflames.dev"; agreedToGuidelines = true; };
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
        gameActivityToggle = {
          enable = true;
          oldIcon = false;
        };
        imageZoom = { enable = true; saveZoomValues = true; zoom = 4.11; };
        memberCount = { enable = true; memberList = true; voiceActivity = true; toolTip = false; };
        messageClickActions = {
          enable = true;
          doubleClickAction = "EDIT";
          singleClickAction = "DELETE";
          tripleClickAction = "REACT";
        };
        messageLogger = { enable = true; logDeletes = true; logEdits = true; };
        moreUserTags = {
          enable = true;
          tagSettings = {
            administrator = { enable = false; };
            chatModerator = { enable = false; };
            moderator = { enable = false; };
            moderatorStaff = { enable = false; };
            owner = { enable = false; };
            voiceModerator = { enable = false; };
            webhook = { enable = false; };
            enable = false;
          };
        };
        newGuildSettings = {
          enable = true;
          messages = 2;
        };
        newPluginsManager = { enable = true; };
        noOnboardingDelay = { enable = true; };
        noTypingAnimation = { enable = true; };
        notificationVolume = { enable = true; notificationVolume = 58.66; };
        pictureInPicture = { enable = true; loop = true; };
        pinDms = {
          enable = true;
        };
        plainFolderIcon = { enable = true; };
        previewMessage = { enable = true; };
        readAllNotificationsButton = { enable = true; };
        relationshipNotifier = { enable = true; };
        reviewDb = { enable = true; };
        serverInfo = { enable = true; sorting = "displayname"; };
        showHiddenChannels = { enable = true; };
        showHiddenThings = { enable = true; };
        silentTyping = { enable = true; };
        spotifyCrack = { enable = true; noSpotifyAutoPause = true; };
        spotifyShareCommands = { enable = true; };
        streamerModeOnStream = { enable = true; };
        translate = { enable = true; receivedOutput = "pl"; sentOutput = "pl"; };
        typingIndicator = { enable = true; };
        typingTweaks = { enable = true; };
        unlockedAvatarZoom = { enable = true; zoomMultiplier = 4.0; };
        userVoiceShow = { enable = true; };
        viewRaw = { enable = true; };
        voiceDownload = { enable = true; };
        voiceMessages = { enable = true; echoCancellation = false; noiseSuppression = false; };
        volumeBooster = { enable = true; multiplier = 2.0; };
        webContextMenus = { enable = true; addBack = true; };
        webKeybinds = { enable = true; };
        webScreenShareFixes = { enable = true; };
        whoReacted = { enable = true; };
        whosWatching = { enable = true; };
        youtubeAdblock = { enable = true; };
        blurNsfw = { enable = true; };
        contentWarning = { enable = true; };
        favouriteAnything = { enable = true; };
      };
    };
    extraConfig.plugins = {
      customCommands = {
        clyde = true;
      };
      fontLoader = {
        applyOnClodeBlocks = false;
      };
      globalBadges = {
        showRa1ncord = true;
      };
      messageClickActions = {
        enableDeleteOnClick = true;
        enableDoubleClickToEdit = false;
        enableDoubleClickToReply = true;
        requireModifier = true;
      };
      noBlockedMessages = {
        applyToIgnoredUsers = true;
        ignoreBlockedMessages = false;
        ignoreMessages = false;
      };
      platformIndicators = {
        badges = true;
      };
      showHiddenChannels = {
        hideUnreads = true;
      };
      showMeYourName = {
        displayNames = false;
        friendNicknames = "dms";
        inReplies = false;
        mode = "user-nick";
      };
      silentTyping = {
        contextMenu = true;
        isEnabled = true;
        showIcon = false;
      };
      translate = {
        shavian = true;
        sitelen = true;
        target = "en";
        toki = true;
        showChatBarButton = true;
      };
    };
  };
}
