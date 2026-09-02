(function () {
  "use strict";

  var dataNode = document.getElementById("surface-data");
  if (!dataNode) return;

  var data;
  try {
    data = JSON.parse(dataNode.textContent || "{}");
  } catch (error) {
    return;
  }

  var state = {
    activeChannel: data.channels[0].id,
    searchOpen: false,
    preferencesOpen: false,
    reactionOpen: false,
    recording: false,
    agentWorking: false,
    agentResult: null,
    resultOpen: false,
    contentOpen: false,
    contentItem: null,
    contentVideoPlaying: false,
    contentFeedbackOpen: false,
    listeningStoryId: "",
    dockCollapsed: false,
    transcript: "",
    transcriptTimer: 0,
    transcriptHideTimer: 0,
    agentFallbackTimer: 0,
    answerStreamTimer: 0,
    answerStreaming: false,
    voicePointerId: null,
    lastFeedScrollTop: 0,
    renderedStoryCount: 0,
    topicStates: Object.create(null),
    customTopics: [],
    toastTimer: 0
  };

  var refs = {
    phone: document.getElementById("phone"),
    discoverView: document.getElementById("discover-view"),
    channelTabs: document.getElementById("channel-tabs"),
    feedScroll: document.getElementById("feed-scroll"),
    leadImage: document.getElementById("lead-image"),
    leadKicker: document.getElementById("lead-kicker"),
    leadTitle: document.getElementById("lead-title"),
    leadSummary: document.getElementById("lead-summary"),
    leadTime: document.getElementById("lead-time"),
    leadStory: document.getElementById("lead-story"),
    secondaryImage: document.getElementById("secondary-image"),
    secondaryKicker: document.getElementById("secondary-kicker"),
    secondaryTitle: document.getElementById("secondary-title"),
    secondarySummary: document.getElementById("secondary-summary"),
    secondaryActions: document.getElementById("secondary-actions"),
    secondaryCard: document.getElementById("secondary-card"),
    moreStories: document.getElementById("more-stories"),
    feedEnd: document.getElementById("feed-end"),
    searchButton: document.getElementById("search-button"),
    searchPanel: document.getElementById("search-panel"),
    searchInput: document.getElementById("search-input"),
    searchCancel: document.getElementById("search-cancel"),
    preferencesButton: document.getElementById("preferences-button"),
    preferencesView: document.getElementById("preferences-view"),
    preferencesClose: document.getElementById("preferences-close"),
    preferenceGroups: document.getElementById("preference-groups"),
    customTopic: document.getElementById("custom-topic"),
    addTopic: document.getElementById("add-topic"),
    customTopicList: document.getElementById("custom-topic-list"),
    listenButton: document.getElementById("listen-button"),
    shareButton: document.getElementById("share-button"),
    moreButton: document.getElementById("more-button"),
    reactionMenu: document.getElementById("reaction-menu"),
    voiceDock: document.getElementById("voice-dock"),
    voiceOrb: document.getElementById("voice-orb"),
    voiceStatus: document.getElementById("voice-status"),
    voiceBubble: document.getElementById("voice-transcript-bubble"),
    voiceTranscript: document.getElementById("voice-transcript"),
    agentResultDock: document.getElementById("agent-result-dock"),
    agentResultCard: document.getElementById("agent-result-card"),
    agentResultHandle: document.getElementById("agent-result-handle"),
    agentResultTool: document.getElementById("agent-result-tool"),
    agentResultLabel: document.getElementById("agent-result-label"),
    agentResultQuestion: document.getElementById("agent-result-question"),
    agentResultTitle: document.getElementById("agent-result-title"),
    agentResultSummary: document.getElementById("agent-result-summary"),
    agentResultFullscreen: document.getElementById("agent-result-fullscreen"),
    agentResultBack: document.getElementById("agent-result-back"),
    agentFullscreenHeading: document.getElementById("agent-fullscreen-heading"),
    agentFullTool: document.getElementById("agent-full-tool"),
    agentFullQuestion: document.getElementById("agent-full-question"),
    agentFullTitle: document.getElementById("agent-full-title"),
    agentFullSummary: document.getElementById("agent-full-summary"),
    agentFullRows: document.getElementById("agent-full-rows"),
    contentFullscreen: document.getElementById("content-fullscreen"),
    contentBack: document.getElementById("content-back"),
    contentFullscreenHeading: document.getElementById("content-fullscreen-heading"),
    contentFullscreenScroll: document.getElementById("content-fullscreen-scroll"),
    contentMedia: document.getElementById("content-media"),
    contentImage: document.getElementById("content-image"),
    contentVideoPlay: document.getElementById("content-video-play"),
    contentVideoDuration: document.getElementById("content-video-duration"),
    contentKicker: document.getElementById("content-kicker"),
    contentTitle: document.getElementById("content-title"),
    contentSummary: document.getElementById("content-summary"),
    contentBody: document.getElementById("content-body"),
    contentListen: document.getElementById("content-listen"),
    contentShare: document.getElementById("content-share"),
    contentMore: document.getElementById("content-more"),
    contentFeedbackMenu: document.getElementById("content-feedback-menu"),
    toast: document.getElementById("toast")
  };

  function el(tagName, className, text) {
    var node = document.createElement(tagName);
    if (className) node.className = className;
    if (typeof text === "string") node.textContent = text;
    return node;
  }

  function showToast(message) {
    window.clearTimeout(state.toastTimer);
    refs.toast.textContent = message;
    refs.toast.classList.add("is-visible");
    state.toastTimer = window.setTimeout(function () {
      refs.toast.classList.remove("is-visible");
    }, 1800);
  }

  function text(value) {
    return value === undefined || value === null ? "" : String(value);
  }

  function iconUse(id) {
    var svg = document.createElementNS("http://www.w3.org/2000/svg", "svg");
    var use = document.createElementNS("http://www.w3.org/2000/svg", "use");
    use.setAttribute("href", "#" + id);
    svg.appendChild(use);
    return svg;
  }

  function normalizedStory(raw) {
    var value = raw && typeof raw === "object" ? raw : {};
    var body = Array.isArray(value.body) ? value.body : [];
    return {
      id: text(value.id || value.title),
      type: value.type === "video" ? "video" : "article",
      source: text(value.source || value.kicker || "Appless 发现"),
      duration: text(value.duration),
      kicker: text(value.kicker || "为你推荐"),
      title: text(value.title || "未命名内容"),
      summary: text(value.summary),
      time: text(value.time),
      image: text(value.image),
      alt: text(value.alt),
      body: body.map(text).filter(Boolean)
    };
  }

  function clearTranscriptTimer() {
    if (!state.transcriptTimer) return;
    window.clearInterval(state.transcriptTimer);
    state.transcriptTimer = 0;
  }

  function setTranscriptBubble(value, sent) {
    state.transcript = text(value).trim();
    refs.voiceTranscript.textContent = state.transcript.length > 0 ? state.transcript : "我在听…";
    refs.voiceBubble.classList.add("is-visible");
    refs.voiceBubble.classList.toggle("is-sent", sent === true);
    refs.voiceBubble.setAttribute("aria-hidden", "false");
  }

  function hideTranscriptBubble(delay) {
    window.clearTimeout(state.transcriptHideTimer);
    state.transcriptHideTimer = window.setTimeout(function () {
      if (state.recording) return;
      refs.voiceBubble.classList.remove("is-visible", "is-sent");
      refs.voiceBubble.setAttribute("aria-hidden", "true");
    }, delay);
  }

  function setAgentWorking(working) {
    state.agentWorking = working;
    refs.voiceDock.classList.toggle("is-working", working);
    refs.voiceStatus.textContent = working ? "Agent 执行中" : (state.recording ? "松开发送" : "按住说话");
    refs.voiceOrb.setAttribute("aria-label", working ? "Agent 正在后台执行" : "按住说话");
    refs.voiceOrb.setAttribute("aria-disabled", String(working));
  }

  function startVoiceRecording(event) {
    if (state.agentWorking || state.recording || state.preferencesOpen) return;
    if (event && typeof event.preventDefault === "function") event.preventDefault();
    state.recording = true;
    state.transcript = "";
    state.voicePointerId = event && event.pointerId !== undefined ? event.pointerId : null;
    if (event && event.pointerId !== undefined && refs.voiceOrb.setPointerCapture) {
      try { refs.voiceOrb.setPointerCapture(event.pointerId); } catch (_error) {}
    }
    refs.voiceDock.classList.add("is-listening");
    refs.voiceStatus.textContent = "松开发送";
    refs.voiceOrb.setAttribute("aria-label", "正在听，松开发送");
    setTranscriptBubble("", false);

    var demo = text(data.agentPrototype && data.agentPrototype.demoTranscript);
    var visibleChars = 0;
    clearTranscriptTimer();
    state.transcriptTimer = window.setInterval(function () {
      if (!state.recording || visibleChars >= demo.length) {
        clearTranscriptTimer();
        return;
      }
      visibleChars = Math.min(demo.length, visibleChars + 2);
      setTranscriptBubble(demo.slice(0, visibleChars), false);
    }, 105);
  }

  function cancelVoiceRecording() {
    if (!state.recording) return;
    clearTranscriptTimer();
    state.recording = false;
    state.voicePointerId = null;
    refs.voiceDock.classList.remove("is-listening");
    refs.voiceStatus.textContent = "按住说话";
    refs.voiceOrb.setAttribute("aria-label", "按住说话");
    hideTranscriptBubble(160);
  }

  function postAgentRequest(prompt) {
    var action = data.agentPrototype && data.agentPrototype.action ? data.agentPrototype.action : null;
    var posted = false;
    if (action && window.AIPhoneHome && typeof window.AIPhoneHome.postAction === "function") {
      try {
        window.AIPhoneHome.postAction(JSON.stringify({
          id: text(action.id),
          label: text(action.label || "语音请求"),
          prompt: prompt,
          variant: text(action.variant || "primary"),
          kind: text(action.kind || "prompt"),
          args: { source: "discovery_voice", surfaceId: "waterfall-interest-home" }
        }));
        posted = true;
      } catch (_error) {
        posted = false;
      }
    }
    if (!posted) {
      window.clearTimeout(state.agentFallbackTimer);
      state.agentFallbackTimer = window.setTimeout(function () {
        if (data.agentPrototype.demoMode === "answer") streamDemoAnswer(data.agentPrototype.demoAnswerResult);
        else showAgentResult(data.agentPrototype.demoToolResult);
      }, 2400);
    }
  }

  function finishVoiceRecording(event) {
    if (!state.recording) return;
    if (event && state.voicePointerId !== null && event.pointerId !== undefined && event.pointerId !== state.voicePointerId) return;
    if (event && typeof event.preventDefault === "function") event.preventDefault();
    clearTranscriptTimer();
    state.recording = false;
    state.voicePointerId = null;
    refs.voiceDock.classList.remove("is-listening");
    var prompt = state.transcript.trim();
    if (!prompt) prompt = text(data.agentPrototype && data.agentPrototype.demoTranscript);
    setTranscriptBubble("已发送：" + prompt, true);
    hideTranscriptBubble(1700);
    setAgentWorking(true);
    postAgentRequest(prompt);
  }

  function normalizedAgentResult(raw) {
    var value = raw;
    if (typeof raw === "string") {
      try { value = JSON.parse(raw); } catch (_error) { value = { title: raw }; }
    }
    if (!value || typeof value !== "object") value = {};
    var rows = Array.isArray(value.rows) ? value.rows.slice(0, 12) : [];
    var resultType = value.type === "answer" ? "answer" : "tool";
    return {
      type: resultType,
      tool: text(value.tool || "Agent 工具结果"),
      question: text(value.question),
      title: text(value.title || "任务已经完成"),
      summary: text(value.summary || "Agent 已完成处理，点开查看完整结果。"),
      answer: text(value.answer || value.summary),
      rows: rows.map(function (row) {
        var safeRow = row && typeof row === "object" ? row : {};
        return {
          title: text(safeRow.title || "结果"),
          meta: text(safeRow.meta),
          detail: text(safeRow.detail)
        };
      })
    };
  }

  function renderAgentResult(result) {
    var isAnswer = result.type === "answer";
    refs.agentResultDock.classList.toggle("is-answer", isAnswer);
    refs.agentResultDock.classList.toggle("is-tool", !isAnswer);
    refs.agentResultFullscreen.classList.toggle("is-answer", isAnswer);
    refs.agentResultFullscreen.classList.toggle("is-tool", !isAnswer);
    refs.agentResultLabel.textContent = isAnswer ? (state.answerStreaming ? "Appless 正在回答" : "Appless 回答") : "Agent 已完成";
    refs.agentResultTool.textContent = result.tool;
    refs.agentResultQuestion.textContent = result.question.length > 0 ? "你问：" + result.question : "";
    refs.agentResultTitle.textContent = isAnswer ? result.answer : result.title;
    refs.agentResultSummary.textContent = isAnswer ? "" : result.summary;
    refs.agentFullscreenHeading.textContent = isAnswer ? "Appless 回答" : "Agent 结果";
    refs.agentFullTool.textContent = result.tool;
    refs.agentFullQuestion.textContent = result.question.length > 0 ? "你问：" + result.question : "";
    refs.agentFullTitle.textContent = result.title;
    refs.agentFullSummary.textContent = isAnswer ? result.answer : result.summary;
    refs.agentFullRows.replaceChildren();
    result.rows.forEach(function (row) {
      var card = el("section", "agent-result-row");
      var title = el("b", "", row.title);
      var meta = el("span", "", row.meta);
      var detail = el("p", "", row.detail);
      card.append(title, meta, detail);
      refs.agentFullRows.appendChild(card);
    });
    if (!isAnswer && result.rows.length === 0) {
      refs.agentFullRows.appendChild(el("p", "agent-page-summary", "没有额外的结构化结果。"));
    }
  }

  function setDockCollapsed(collapsed) {
    if (!state.agentResult) return;
    state.dockCollapsed = collapsed;
    refs.agentResultDock.classList.toggle("is-collapsed", collapsed);
  }

  function showAgentResult(raw) {
    window.clearTimeout(state.agentFallbackTimer);
    window.clearInterval(state.answerStreamTimer);
    state.agentFallbackTimer = 0;
    state.answerStreamTimer = 0;
    state.answerStreaming = false;
    state.agentResult = normalizedAgentResult(raw);
    renderAgentResult(state.agentResult);
    setAgentWorking(false);
    setDockCollapsed(false);
    refs.agentResultDock.classList.add("is-visible");
    refs.agentResultDock.setAttribute("aria-hidden", "false");
    showToast(state.agentResult.type === "answer" ? "Appless 已回答，卡片已常驻顶部" : "Agent 已完成，结果卡已常驻顶部");
  }

  function streamDemoAnswer(raw) {
    window.clearInterval(state.answerStreamTimer);
    var complete = normalizedAgentResult(raw);
    var completeAnswer = complete.answer;
    var visibleChars = 0;
    state.answerStreaming = true;
    complete.answer = "";
    state.agentResult = complete;
    renderAgentResult(state.agentResult);
    setAgentWorking(true);
    setDockCollapsed(false);
    refs.agentResultDock.classList.add("is-visible");
    refs.agentResultDock.setAttribute("aria-hidden", "false");
    state.answerStreamTimer = window.setInterval(function () {
      visibleChars = Math.min(completeAnswer.length, visibleChars + 2);
      state.agentResult.answer = completeAnswer.slice(0, visibleChars);
      renderAgentResult(state.agentResult);
      if (visibleChars >= completeAnswer.length) {
        window.clearInterval(state.answerStreamTimer);
        state.answerStreamTimer = 0;
        state.answerStreaming = false;
        renderAgentResult(state.agentResult);
        setAgentWorking(false);
        showToast("Appless 已回答，卡片已常驻顶部");
      }
    }, 44);
  }

  function notifyWaterfallFullscreen(active) {
    if (!window.AIPhoneHome || typeof window.AIPhoneHome.setWaterfallFullscreen !== "function") return;
    try { window.AIPhoneHome.setWaterfallFullscreen(active ? "true" : "false"); } catch (_error) {}
  }

  function syncWaterfallFullscreen() {
    notifyWaterfallFullscreen(state.resultOpen || state.contentOpen);
  }

  function setAgentResultOpen(open) {
    if (open && !state.agentResult) return;
    state.resultOpen = open;
    refs.phone.classList.toggle("agent-fullscreen-open", open);
    refs.agentResultFullscreen.classList.toggle("is-open", open);
    refs.agentResultFullscreen.setAttribute("aria-hidden", String(!open));
    syncWaterfallFullscreen();
  }

  function closeContentFeedback() {
    state.contentFeedbackOpen = false;
    refs.contentFeedbackMenu.classList.remove("is-open");
    refs.contentFeedbackMenu.setAttribute("aria-hidden", "true");
    refs.contentMore.setAttribute("aria-expanded", "false");
  }

  function setContentListenState(button, story) {
    var active = state.listeningStoryId === story.id;
    button.classList.toggle("is-active", active);
    var label = button.querySelector("span");
    if (label) label.textContent = active ? "停止" : "听报道";
  }

  function toggleStoryListen(story, button) {
    state.listeningStoryId = state.listeningStoryId === story.id ? "" : story.id;
    setContentListenState(button, story);
    document.querySelectorAll(".feed-listen-button").forEach(function (feedButton) {
      var active = feedButton.dataset.storyId === state.listeningStoryId;
      feedButton.classList.toggle("is-active", active);
      var feedLabel = feedButton.querySelector("span");
      if (feedLabel) feedLabel.textContent = active ? "停止" : "听报道";
    });
    setContentListenState(refs.listenButton, normalizedStory(activeArticle()));
    if (state.contentOpen && state.contentItem && state.contentItem.id === story.id) {
      setContentListenState(refs.contentListen, story);
    }
    showToast(state.listeningStoryId ? "正在朗读“" + story.title + "”" : "已停止朗读");
  }

  function renderContent(story) {
    var item = normalizedStory(story);
    state.contentItem = item;
    state.contentVideoPlaying = false;
    refs.contentFullscreen.classList.toggle("is-video", item.type === "video");
    refs.contentFullscreen.classList.remove("is-playing");
    refs.contentFullscreenHeading.textContent = item.type === "video" ? "视频" : "阅读";
    refs.contentImage.src = item.image;
    refs.contentImage.alt = item.alt;
    refs.contentVideoDuration.textContent = item.duration;
    refs.contentVideoPlay.setAttribute("aria-label", "播放视频");
    refs.contentKicker.textContent = item.source + (item.kicker ? " · " + item.kicker : "") + (item.time ? " · " + item.time : "");
    refs.contentTitle.textContent = item.title;
    refs.contentSummary.textContent = item.summary;
    refs.contentBody.replaceChildren();
    var paragraphs = item.body.length > 0 ? item.body : [
      "围绕这一主题，内容进一步梳理了事情发生的背景、正在出现的变化，以及这些变化如何进入普通人的日常生活。",
      "完整阅读不仅保留了发现流中的核心信息，也提供了更连贯的上下文。你可以随时分享、听报道，或反馈是否喜欢这类内容。"
    ];
    paragraphs.filter(Boolean).forEach(function (paragraph) {
      refs.contentBody.appendChild(el("p", "", paragraph));
    });
    setContentListenState(refs.contentListen, item);
    closeContentFeedback();
  }

  function openContent(story) {
    renderContent(story);
    state.contentOpen = true;
    refs.phone.classList.add("content-fullscreen-open");
    refs.contentFullscreen.classList.add("is-open");
    refs.contentFullscreen.setAttribute("aria-hidden", "false");
    refs.contentFullscreenScroll.scrollTop = 0;
    syncWaterfallFullscreen();
  }

  function closeContent() {
    state.contentOpen = false;
    state.contentVideoPlaying = false;
    refs.phone.classList.remove("content-fullscreen-open");
    refs.contentFullscreen.classList.remove("is-open", "is-playing");
    refs.contentFullscreen.setAttribute("aria-hidden", "true");
    closeContentFeedback();
    syncWaterfallFullscreen();
  }

  function createFeedActionBar(story) {
    var item = normalizedStory(story);
    var row = el("div", "feed-card-action-row");
    var time = el("time", "", item.time);
    var actions = el("div", "feed-card-actions");
    var listen = el("button", "feed-listen-button");
    var share = el("button");
    var more = el("button");
    var menu = el("div", "feed-feedback-menu");
    var like = el("button");
    var dislike = el("button");

    listen.type = share.type = more.type = like.type = dislike.type = "button";
    listen.setAttribute("aria-label", "听报道");
    listen.dataset.storyId = item.id;
    share.setAttribute("aria-label", "分享");
    more.setAttribute("aria-label", "反馈");
    more.setAttribute("aria-expanded", "false");
    menu.setAttribute("aria-hidden", "true");
    menu.setAttribute("role", "menu");
    like.setAttribute("role", "menuitem");
    dislike.setAttribute("role", "menuitem");
    listen.append(iconUse("i-headphones"), el("span", "", "听报道"));
    share.appendChild(iconUse("i-share"));
    more.appendChild(iconUse("i-more"));
    like.append(iconUse("i-like"), el("span", "", "喜欢"));
    dislike.append(iconUse("i-dislike"), el("span", "", "不喜欢"));
    menu.append(like, dislike);
    actions.append(listen, share, more);
    row.append(time, actions, menu);
    setContentListenState(listen, item);

    listen.addEventListener("click", function (event) {
      event.stopPropagation();
      toggleStoryListen(item, listen);
    });
    share.addEventListener("click", function (event) {
      event.stopPropagation();
      showToast("分享“" + item.title + "”");
    });
    more.addEventListener("click", function (event) {
      event.stopPropagation();
      document.querySelectorAll(".feed-feedback-menu.is-open").forEach(function (openMenu) {
        if (openMenu !== menu) openMenu.classList.remove("is-open");
      });
      var open = !menu.classList.contains("is-open");
      menu.classList.toggle("is-open", open);
      menu.setAttribute("aria-hidden", String(!open));
      more.setAttribute("aria-expanded", String(open));
    });
    menu.addEventListener("click", function (event) {
      event.stopPropagation();
      var button = event.target.closest("button");
      if (!button) return;
      showToast(button === like ? "会为你推荐更多类似内容" : "会为你减少类似内容");
      menu.classList.remove("is-open");
      menu.setAttribute("aria-hidden", "true");
      more.setAttribute("aria-expanded", "false");
    });
    return row;
  }

  function activeArticle() {
    return data.articles.find(function (article) {
      return article.channel === state.activeChannel;
    }) || data.articles[0];
  }

  function renderChannels() {
    refs.channelTabs.replaceChildren();
    data.channels.forEach(function (channel) {
      var button = el("button", "channel-tab", channel.label);
      button.type = "button";
      button.setAttribute("role", "tab");
      button.setAttribute("aria-selected", String(channel.id === state.activeChannel));
      button.classList.toggle("is-active", channel.id === state.activeChannel);
      button.addEventListener("click", function () {
        if (state.activeChannel === channel.id) return;
        state.activeChannel = channel.id;
        closeReactionMenu();
        renderChannels();
        renderArticle(true);
      });
      refs.channelTabs.appendChild(button);
    });
  }

  function renderArticle(resetScroll) {
    var article = normalizedStory(activeArticle());
    var secondary = normalizedStory(data.secondary);
    refs.leadImage.src = article.image;
    refs.leadImage.alt = article.alt;
    refs.leadKicker.textContent = article.kicker;
    refs.leadTitle.textContent = article.title;
    refs.leadSummary.textContent = article.summary;
    refs.leadTime.textContent = article.time;
    setContentListenState(refs.listenButton, article);
    refs.leadStory.setAttribute("aria-label", "打开“" + article.title + "”");
    refs.secondaryImage.src = secondary.image;
    refs.secondaryImage.alt = secondary.alt;
    refs.secondaryKicker.textContent = secondary.kicker;
    refs.secondaryTitle.textContent = secondary.title;
    refs.secondarySummary.textContent = secondary.summary;
    refs.secondaryCard.setAttribute("aria-label", "打开“" + secondary.title + "”");
    refs.secondaryActions.replaceChildren(createFeedActionBar(secondary));
    if (resetScroll) refs.feedScroll.scrollTo({ top: 0, behavior: "smooth" });
  }

  function createFeedStory(story) {
    var item = normalizedStory(story);
    var article = el("article", "feed-story-card");
    article.tabIndex = 0;
    article.setAttribute("aria-label", "打开“" + item.title + "”");

    var media = el("div", "feed-story-media" + (item.type === "video" ? " is-video" : ""));
    var image = el("img");
    image.src = item.image;
    image.alt = item.alt;
    image.loading = "lazy";
    image.draggable = false;
    media.appendChild(image);
    if (item.type === "video") {
      var play = el("button", "feed-video-play");
      play.type = "button";
      play.setAttribute("aria-label", "播放“" + item.title + "”");
      play.appendChild(el("span"));
      play.addEventListener("click", function (event) {
        event.stopPropagation();
        openContent(item);
      });
      media.append(play, el("span", "feed-video-duration", item.duration));
    }

    var kicker = el("p", "story-kicker", item.source + " · " + item.kicker);
    var title = el("h2", "", item.title);
    var summary = el("p", "feed-story-summary", item.summary);
    article.append(media, kicker, title, summary, createFeedActionBar(item));
    article.addEventListener("click", function (event) {
      if (event.target.closest("button")) return;
      openContent(item);
    });
    article.addEventListener("keydown", function (event) {
      if ((event.key === "Enter" || event.key === " ") && !event.target.closest("button")) {
        event.preventDefault();
        openContent(item);
      }
    });
    return article;
  }

  function appendMoreStories(batchSize) {
    var stories = Array.isArray(data.moreStories) ? data.moreStories : [];
    var endIndex = Math.min(state.renderedStoryCount + batchSize, stories.length);
    for (var index = state.renderedStoryCount; index < endIndex; index += 1) {
      refs.moreStories.appendChild(createFeedStory(stories[index]));
    }
    state.renderedStoryCount = endIndex;
    refs.feedEnd.textContent = state.renderedStoryCount < stories.length ? "继续上滑，加载更多内容" : "已加载全部推荐内容";
  }

  function nextTopicState(topic) {
    var current = state.topicStates[topic] || "neutral";
    if (current === "neutral") return "positive";
    if (current === "positive") return "negative";
    return "neutral";
  }

  function applyTopicState(button, topic) {
    var topicState = state.topicStates[topic] || "neutral";
    button.classList.toggle("is-positive", topicState === "positive");
    button.classList.toggle("is-negative", topicState === "negative");
    button.setAttribute("aria-pressed", String(topicState === "positive"));
  }

  function createTopicButton(topic) {
    var button = el("button", "topic-chip", topic);
    button.type = "button";
    applyTopicState(button, topic);
    button.addEventListener("click", function () {
      state.topicStates[topic] = nextTopicState(topic);
      renderTopics();
      var topicState = state.topicStates[topic];
      if (topicState === "positive") showToast("将为你增加“" + topic + "”内容");
      else if (topicState === "negative") showToast("将减少“" + topic + "”内容");
      else showToast("已恢复“" + topic + "”默认推荐");
    });
    return button;
  }

  function renderTopics() {
    refs.preferenceGroups.replaceChildren();
    data.preferenceGroups.forEach(function (group) {
      var section = el("section", "preference-group");
      var heading = el("h3", "", group.title);
      var cloud = el("div", "topic-cloud");
      group.topics.forEach(function (topic) {
        cloud.appendChild(createTopicButton(topic));
      });
      section.append(heading, cloud);
      refs.preferenceGroups.appendChild(section);
    });

    refs.customTopicList.replaceChildren();
    state.customTopics.forEach(function (topic) {
      refs.customTopicList.appendChild(createTopicButton(topic));
    });
  }

  function setSearchOpen(open) {
    state.searchOpen = open;
    refs.discoverView.classList.toggle("search-open", open);
    refs.searchPanel.classList.toggle("is-open", open);
    refs.searchPanel.setAttribute("aria-hidden", String(!open));
    if (open) {
      window.setTimeout(function () { refs.searchInput.focus(); }, 280);
    } else {
      refs.searchInput.value = "";
      refs.searchButton.focus();
    }
  }

  function setPreferencesOpen(open) {
    state.preferencesOpen = open;
    refs.phone.classList.toggle("preferences-open", open);
    refs.preferencesView.classList.toggle("is-open", open);
    refs.preferencesView.setAttribute("aria-hidden", String(!open));
    closeReactionMenu();
  }

  function closeReactionMenu() {
    state.reactionOpen = false;
    refs.reactionMenu.classList.remove("is-open");
    refs.reactionMenu.setAttribute("aria-hidden", "true");
    refs.moreButton.setAttribute("aria-expanded", "false");
  }

  function toggleReactionMenu() {
    state.reactionOpen = !state.reactionOpen;
    refs.reactionMenu.classList.toggle("is-open", state.reactionOpen);
    refs.reactionMenu.setAttribute("aria-hidden", String(!state.reactionOpen));
    refs.moreButton.setAttribute("aria-expanded", String(state.reactionOpen));
  }

  function addCustomTopic() {
    var topic = refs.customTopic.value.trim();
    if (!topic) {
      showToast("请输入你想看的主题");
      return;
    }
    if (state.customTopics.indexOf(topic) !== -1) {
      showToast("这个主题已经添加过了");
      return;
    }
    state.customTopics.push(topic);
    state.topicStates[topic] = "positive";
    refs.customTopic.value = "";
    renderTopics();
    showToast("已添加“" + topic + "”");
  }

  refs.searchButton.addEventListener("click", function () { setSearchOpen(!state.searchOpen); });
  refs.searchCancel.addEventListener("click", function () { setSearchOpen(false); });
  refs.searchInput.addEventListener("keydown", function (event) {
    if (event.key === "Enter" && refs.searchInput.value.trim()) showToast("正在搜索“" + refs.searchInput.value.trim() + "”");
  });
  refs.preferencesButton.addEventListener("click", function () { setPreferencesOpen(true); });
  refs.preferencesClose.addEventListener("click", function () { setPreferencesOpen(false); });
  refs.addTopic.addEventListener("click", addCustomTopic);
  refs.customTopic.addEventListener("keydown", function (event) { if (event.key === "Enter") addCustomTopic(); });

  refs.listenButton.addEventListener("click", function (event) {
    event.stopPropagation();
    var article = normalizedStory(activeArticle());
    toggleStoryListen(article, refs.listenButton);
  });
  refs.shareButton.addEventListener("click", function (event) {
    event.stopPropagation();
    showToast("分享“" + normalizedStory(activeArticle()).title + "”");
  });
  refs.moreButton.addEventListener("click", function (event) {
    event.stopPropagation();
    toggleReactionMenu();
  });
  refs.reactionMenu.addEventListener("click", function (event) {
    event.stopPropagation();
    var button = event.target.closest("button[data-reaction]");
    if (!button) return;
    Array.prototype.forEach.call(refs.reactionMenu.querySelectorAll("button"), function (item) {
      item.classList.toggle("is-selected", item === button);
    });
    showToast(button.dataset.reaction === "like" ? "会为你推荐更多类似内容" : "会为你减少类似内容");
    closeReactionMenu();
  });

  refs.leadStory.addEventListener("click", function (event) {
    if (event.target.closest("button")) return;
    openContent(activeArticle());
  });
  refs.leadStory.addEventListener("keydown", function (event) {
    if ((event.key === "Enter" || event.key === " ") && !event.target.closest("button")) {
      event.preventDefault();
      openContent(activeArticle());
    }
  });
  document.getElementById("see-more-button").addEventListener("click", function (event) {
    event.stopPropagation();
    openContent(activeArticle());
  });
  refs.secondaryCard.addEventListener("click", function (event) {
    if (event.target.closest("button")) return;
    openContent(data.secondary);
  });
  refs.secondaryCard.addEventListener("keydown", function (event) {
    if ((event.key === "Enter" || event.key === " ") && !event.target.closest("button")) {
      event.preventDefault();
      openContent(data.secondary);
    }
  });
  refs.contentBack.addEventListener("click", closeContent);
  refs.contentVideoPlay.addEventListener("click", function () {
    if (!state.contentItem || state.contentItem.type !== "video") return;
    state.contentVideoPlaying = !state.contentVideoPlaying;
    refs.contentFullscreen.classList.toggle("is-playing", state.contentVideoPlaying);
    refs.contentVideoPlay.setAttribute("aria-label", state.contentVideoPlaying ? "暂停视频" : "播放视频");
    showToast(state.contentVideoPlaying ? "视频开始播放" : "视频已暂停");
  });
  refs.contentListen.addEventListener("click", function () {
    if (state.contentItem) toggleStoryListen(state.contentItem, refs.contentListen);
  });
  refs.contentShare.addEventListener("click", function () {
    if (state.contentItem) showToast("分享“" + state.contentItem.title + "”");
  });
  refs.contentMore.addEventListener("click", function (event) {
    event.stopPropagation();
    state.contentFeedbackOpen = !state.contentFeedbackOpen;
    refs.contentFeedbackMenu.classList.toggle("is-open", state.contentFeedbackOpen);
    refs.contentFeedbackMenu.setAttribute("aria-hidden", String(!state.contentFeedbackOpen));
    refs.contentMore.setAttribute("aria-expanded", String(state.contentFeedbackOpen));
  });
  refs.contentFeedbackMenu.addEventListener("click", function (event) {
    event.stopPropagation();
    var button = event.target.closest("button[data-content-reaction]");
    if (!button) return;
    showToast(button.dataset.contentReaction === "like" ? "会为你推荐更多类似内容" : "会为你减少类似内容");
    closeContentFeedback();
  });
  refs.voiceOrb.addEventListener("pointerdown", startVoiceRecording);
  refs.voiceOrb.addEventListener("pointerup", finishVoiceRecording);
  refs.voiceOrb.addEventListener("pointercancel", cancelVoiceRecording);
  refs.voiceOrb.addEventListener("contextmenu", function (event) { event.preventDefault(); });
  refs.voiceOrb.addEventListener("keydown", function (event) {
    if ((event.key === " " || event.key === "Enter") && !event.repeat) startVoiceRecording(event);
  });
  refs.voiceOrb.addEventListener("keyup", function (event) {
    if (event.key === " " || event.key === "Enter") finishVoiceRecording(event);
  });
  refs.agentResultCard.addEventListener("click", function () { setAgentResultOpen(true); });
  refs.agentResultHandle.addEventListener("click", function () { setDockCollapsed(false); });
  refs.agentResultBack.addEventListener("click", function () { setAgentResultOpen(false); });
  refs.feedScroll.addEventListener("scroll", function () {
    var remaining = refs.feedScroll.scrollHeight - refs.feedScroll.scrollTop - refs.feedScroll.clientHeight;
    if (remaining < 320 && state.renderedStoryCount < data.moreStories.length) appendMoreStories(2);
    var nextTop = refs.feedScroll.scrollTop;
    if (state.agentResult && !state.resultOpen) {
      if (nextTop > state.lastFeedScrollTop + 5 && nextTop > 36) setDockCollapsed(true);
      else if (nextTop < state.lastFeedScrollTop - 8) setDockCollapsed(false);
    }
    state.lastFeedScrollTop = nextTop;
  }, { passive: true });
  document.addEventListener("click", function (event) {
    if (state.reactionOpen && !refs.reactionMenu.contains(event.target) && !refs.moreButton.contains(event.target)) closeReactionMenu();
    if (state.contentFeedbackOpen && !refs.contentFeedbackMenu.contains(event.target) && !refs.contentMore.contains(event.target)) closeContentFeedback();
    document.querySelectorAll(".feed-feedback-menu.is-open").forEach(function (menu) {
      if (!menu.contains(event.target)) {
        menu.classList.remove("is-open");
        menu.setAttribute("aria-hidden", "true");
        var button = menu.parentElement && menu.parentElement.querySelector("button[aria-expanded]");
        if (button) button.setAttribute("aria-expanded", "false");
      }
    });
  });
  document.addEventListener("keydown", function (event) {
    if (event.key !== "Escape") return;
    if (state.contentOpen) closeContent();
    else if (state.resultOpen) setAgentResultOpen(false);
    else if (state.preferencesOpen) setPreferencesOpen(false);
    else if (state.reactionOpen) closeReactionMenu();
    else if (state.searchOpen) setSearchOpen(false);
  });

  window.ApplessDiscoveryAgent = Object.freeze({
    updateTranscript: function (value) {
      if (!state.recording) return;
      clearTranscriptTimer();
      setTranscriptBubble(text(value), false);
    },
    setWorking: function (working) {
      setAgentWorking(Boolean(working));
    },
    showResult: function (payload) {
      showAgentResult(payload);
    },
    showError: function (message) {
      window.clearTimeout(state.agentFallbackTimer);
      setAgentWorking(false);
      showToast(text(message) || "Agent 执行失败，请稍后重试");
    }
  });

  renderChannels();
  renderArticle(false);
  renderTopics();
  appendMoreStories(3);
})();
