(() => {
  "use strict";

  const $ = (selector, root = document) => root.querySelector(selector);
  const $$ = (selector, root = document) => [...root.querySelectorAll(selector)];

  document.addEventListener("keydown", (event) => {
    if (event.key === "Tab") document.body.classList.add("keyboard-navigation");
  });
  document.addEventListener("pointerdown", () => document.body.classList.remove("keyboard-navigation"));

  const deviceSlot = $("#deviceSlot");
  const deviceWrap = $("#deviceWrap");
  const prototypeNavigationShell = $("#prototypeNavigationShell");
  const prototypeNavigator = $("#prototypeNavigator");
  const prototypePills = $(".prototype-pills", prototypeNavigator);
  const prototypeNowButton = $("#prototypeNowButton");
  const prototypeNowMenu = $("#prototypeNowMenu");
  const prototypeNowItems = $$('[data-now-scene]', prototypeNowMenu);
  const prototypeActivityButton = $('[data-prototype="activity"]', prototypeNavigator);
  const prototypeActivityMenu = $("#prototypeActivityMenu");
  const prototypeActivityItems = $$('[data-activity-page]', prototypeActivityMenu);
  const deviceScreen = $("#deviceScreen");
  const homeView = $("#homeView");
  const homeContent = $("#homeContent");
  const currentActivity = $("#currentActivity");
  const homeActivityCards = $$('[data-home-activity-card]', currentActivity);
  const activitySpace = $("#activitySpace");
  const activityPageViews = $$('[data-activity-page-view]', activitySpace);
  const spaceBack = $("#spaceBack");
  const bottomSystem = $("#bottomSystem");
  const homeDateTrigger = $("#homeDateTrigger");
  const calendarLaunchPill = $("#calendarLaunchPill");
  const calendarView = $("#calendarView");
  const calendarViewScroll = $("#calendarViewScroll");
  const calendarBack = $("#calendarBack");
  const calendarModeButtons = $$(".calendar-mode-switch button", calendarView);
  const toast = $("#toast");
  const diningScene = $("#diningScene");
  const diningQueryProcessing = $("#diningQueryProcessing");
  const diningQuerySteps = $("#diningQuerySteps");
  const diningResults = $("#diningResults");
  const diningResultsScroll = $("#diningResultsScroll");
  const diningCategoryFilters = $$(".dining-category-filters .dining-filter", diningResults);
  const diningOptionFilters = $$(".dining-option-filter", diningResults);
  const diningFeaturedRestaurant = $("#diningFeaturedRestaurant");
  const diningDetailProcessing = $("#diningDetailProcessing");
  const diningDetailSteps = $("#diningDetailSteps");
  const diningDetail = $("#diningDetail");
  const diningDetailScroll = $("#diningDetailScroll");
  const diningDetailBack = $("#diningDetailBack");
  const travelScene = $("#travelScene");
  const travelQueryProcessing = $("#travelQueryProcessing");
  const travelQuerySteps = $("#travelQuerySteps");
  const travelResults = $("#travelResults");
  const travelResultsScroll = $("#travelResultsScroll");
  const travelFlightOptions = $$(".travel-flight-option", travelResults);
  const travelFlightFilters = $$(".travel-flight-filter", travelResults);
  const travelRoute = $(".travel-route", travelResults);
  const travelOriginSelect = $("#travelOriginSelect");
  const travelDestinationSelect = $("#travelDestinationSelect");
  const travelOriginDisplay = $("#travelOriginDisplay");
  const travelDestinationDisplay = $("#travelDestinationDisplay");
  const travelFlightRouteCopies = $$(".travel-flight-route-copy", travelResults);
  let toastTimer;
  let currentNowScene = "home";
  let diningState = "idle";
  let diningRunToken = 0;
  let diningTimers = [];
  let diningSavedResultsScroll = 0;
  let travelState = "idle";
  let travelRunToken = 0;
  let travelTimers = [];
  let currentActivityPage = "aios";
  let homeActivityIndex = 0;
  let homeActivityPointerId = null;
  let homeActivityDragStartX = 0;
  let homeActivityDragX = 0;
  let homeActivityWasDragged = false;
  let suppressHomeActivityClick = false;
  let prototypePillsPointerId = null;
  let prototypePillsDragStartX = 0;
  let prototypePillsScrollStart = 0;
  let prototypePillsWasDragged = false;
  let suppressPrototypePillClick = false;

  function finishPrototypePillsDrag(event) {
    if (event.pointerId !== prototypePillsPointerId) return;
    if (prototypePills.hasPointerCapture(event.pointerId)) prototypePills.releasePointerCapture(event.pointerId);
    prototypePillsPointerId = null;
    prototypePills.classList.remove("is-dragging");
    if (prototypePillsWasDragged) {
      suppressPrototypePillClick = true;
      window.setTimeout(() => { suppressPrototypePillClick = false; }, 180);
    }
  }

  prototypePills.addEventListener("pointerdown", (event) => {
    if (event.pointerType === "mouse" && event.button !== 0) return;
    prototypePillsPointerId = event.pointerId;
    prototypePillsDragStartX = event.clientX;
    prototypePillsScrollStart = prototypePills.scrollLeft;
    prototypePillsWasDragged = false;
  });

  prototypePills.addEventListener("pointermove", (event) => {
    if (event.pointerId !== prototypePillsPointerId) return;
    const deltaX = event.clientX - prototypePillsDragStartX;
    if (!prototypePillsWasDragged && Math.abs(deltaX) < 4) return;
    if (!prototypePillsWasDragged) prototypePills.setPointerCapture(event.pointerId);
    prototypePillsWasDragged = true;
    prototypePills.classList.add("is-dragging");
    prototypePills.scrollLeft = prototypePillsScrollStart - deltaX;
    event.preventDefault();
  });

  prototypePills.addEventListener("pointerup", finishPrototypePillsDrag);
  prototypePills.addEventListener("pointercancel", finishPrototypePillsDrag);
  prototypePills.addEventListener("click", (event) => {
    if (!suppressPrototypePillClick) return;
    event.preventDefault();
    event.stopImmediatePropagation();
    suppressPrototypePillClick = false;
  }, true);

  function fitDevice() {
    const edge = 20;
    const previewWidth = deviceWrap.offsetWidth;
    const previewHeight = deviceWrap.offsetHeight;
    const navigatorHeight = prototypeNavigator.offsetHeight;
    const availableHeight = window.innerHeight - navigatorHeight - 52;
    const scale = Math.max(0.45, Math.min(1, availableHeight / previewHeight, (window.innerWidth - edge * 2) / previewWidth));
    deviceWrap.style.transform = `scale(${scale})`;
    deviceSlot.style.width = `${previewWidth * scale}px`;
    deviceSlot.style.height = `${previewHeight * scale}px`;
  }

  function setPrototypeActive(state) {
    $$("[data-prototype]", prototypeNavigator).forEach((button) => {
      const active = button.dataset.prototype === state;
      button.classList.toggle("active", active);
      active ? button.setAttribute("aria-current", "page") : button.removeAttribute("aria-current");
      if (active) button.scrollIntoView({ behavior: "smooth", block: "nearest", inline: "nearest" });
    });
  }

  function positionPrototypeActivityMenu() {
    const shellRect = prototypeNavigationShell.getBoundingClientRect();
    const buttonRect = prototypeActivityButton.getBoundingClientRect();
    const menuWidth = prototypeActivityMenu.offsetWidth || 196;
    const requestedLeft = buttonRect.left - shellRect.left + buttonRect.width / 2 - menuWidth / 2;
    const left = Math.max(6, Math.min(shellRect.width - menuWidth - 6, requestedLeft));
    prototypeActivityMenu.style.setProperty("--activity-menu-left", `${left}px`);
  }

  function positionPrototypeNowMenu() {
    const shellRect = prototypeNavigationShell.getBoundingClientRect();
    const buttonRect = prototypeNowButton.getBoundingClientRect();
    const menuWidth = prototypeNowMenu.offsetWidth || 196;
    const requestedLeft = buttonRect.left - shellRect.left + buttonRect.width / 2 - menuWidth / 2;
    const left = Math.max(6, Math.min(shellRect.width - menuWidth - 6, requestedLeft));
    prototypeNowMenu.style.setProperty("--activity-menu-left", `${left}px`);
  }

  function closePrototypeNowMenu({ restoreFocus = false } = {}) {
    if (!prototypeNowMenu.classList.contains("open")) return;
    prototypeNowMenu.classList.remove("open");
    prototypeNowMenu.setAttribute("aria-hidden", "true");
    prototypeNowButton.setAttribute("aria-expanded", "false");
    if (restoreFocus) prototypeNowButton.focus({ preventScroll: true });
  }

  function openPrototypeNowMenu() {
    closePrototypeActivityMenu();
    positionPrototypeNowMenu();
    prototypeNowMenu.classList.add("open");
    prototypeNowMenu.setAttribute("aria-hidden", "false");
    prototypeNowButton.setAttribute("aria-expanded", "true");
  }

  function closePrototypeActivityMenu({ restoreFocus = false } = {}) {
    if (!prototypeActivityMenu.classList.contains("open")) return;
    prototypeActivityMenu.classList.remove("open");
    prototypeActivityMenu.setAttribute("aria-hidden", "true");
    prototypeActivityButton.setAttribute("aria-expanded", "false");
    if (restoreFocus) prototypeActivityButton.focus({ preventScroll: true });
  }

  function openPrototypeActivityMenu() {
    closePrototypeNowMenu();
    positionPrototypeActivityMenu();
    prototypeActivityMenu.classList.add("open");
    prototypeActivityMenu.setAttribute("aria-hidden", "false");
    prototypeActivityButton.setAttribute("aria-expanded", "true");
  }

  function setActivityPage(page, { focusTitle = false } = {}) {
    if (!activityPageViews.some((view) => view.dataset.activityPageView === page)) return;
    currentActivityPage = page;
    activityPageViews.forEach((view) => {
      const active = view.dataset.activityPageView === page;
      view.hidden = !active;
      view.classList.toggle("active", active);
    });
    prototypeActivityItems.forEach((item) => item.setAttribute("aria-checked", String(item.dataset.activityPage === page)));

    const spaceScroll = $(".space-scroll", activitySpace);
    if (activitySpace.classList.contains("active")) spaceScroll.scrollTo({ top: 0, behavior: "auto" });
    if (focusTitle && activitySpace.classList.contains("active")) {
      const activeTitle = $("h1", activityPageViews.find((view) => view.dataset.activityPageView === page));
      window.setTimeout(() => activeTitle.focus({ preventScroll: true }), 40);
    }
  }

  function updateHomeActivityCarousel({ syncActivity = true, focus = false } = {}) {
    const cardCount = homeActivityCards.length;
    if (!cardCount) return;
    homeActivityCards.forEach((card, index) => {
      const position = (index - homeActivityIndex + cardCount) % cardCount;
      const active = position === 0;
      card.classList.toggle("is-active", active);
      card.classList.toggle("is-next", position === 1);
      card.classList.toggle("is-previous", position > 1);
      card.setAttribute("aria-hidden", String(!active));
      active ? card.setAttribute("aria-current", "true") : card.removeAttribute("aria-current");
      card.tabIndex = active ? 0 : -1;
    });
    currentActivity.style.removeProperty("--home-activity-drag");
    const activeCard = homeActivityCards[homeActivityIndex];
    if (syncActivity) setActivityPage(activeCard.dataset.activityPage);
    if (focus) activeCard.focus({ preventScroll: true });
  }

  function moveHomeActivity(direction, { focus = false } = {}) {
    homeActivityIndex = (homeActivityIndex + direction + homeActivityCards.length) % homeActivityCards.length;
    updateHomeActivityCarousel({ focus });
  }

  function openHomeActivityCard(card) {
    if (!card) return;
    const targetIndex = homeActivityCards.indexOf(card);
    if (targetIndex < 0) return;
    if (targetIndex !== homeActivityIndex) {
      homeActivityIndex = targetIndex;
      updateHomeActivityCarousel({ syncActivity: false });
    }
    setActivityPage(card.dataset.activityPage);
    enterActivity();
  }

  function finishHomeActivityDrag(event, { cancelled = false } = {}) {
    if (event.pointerId !== homeActivityPointerId) return;
    const dragDistance = homeActivityDragX;
    const dragged = homeActivityWasDragged;
    const opensActiveCard = !cancelled && !dragged;
    currentActivity.classList.remove("is-dragging");
    currentActivity.style.removeProperty("--home-activity-drag");
    if (currentActivity.hasPointerCapture(event.pointerId)) currentActivity.releasePointerCapture(event.pointerId);
    homeActivityPointerId = null;
    homeActivityDragX = 0;
    homeActivityWasDragged = false;
    if (!cancelled && Math.abs(dragDistance) >= 46) moveHomeActivity(dragDistance < 0 ? 1 : -1);
    if (dragged || opensActiveCard) {
      suppressHomeActivityClick = true;
      window.setTimeout(() => { suppressHomeActivityClick = false; }, 0);
    }
    if (opensActiveCard) openHomeActivityCard(homeActivityCards[homeActivityIndex]);
  }

  updateHomeActivityCarousel({ syncActivity: false });

  function showToast(message) {
    window.clearTimeout(toastTimer);
    toast.textContent = message;
    toast.classList.add("visible");
    toastTimer = window.setTimeout(() => toast.classList.remove("visible"), 2200);
  }

  function updateStatusTime() {
    const value = new Intl.DateTimeFormat("en", { hour: "numeric", minute: "2-digit", hour12: false }).format(new Date());
    $("#statusTime").textContent = value;
    const homeClock = $("#homeClock");
    if (homeClock) homeClock.textContent = value;
  }

  fitDevice();
  updateStatusTime();
  window.addEventListener("resize", () => {
    fitDevice();
    if (prototypeNowMenu.classList.contains("open")) positionPrototypeNowMenu();
    if (prototypeActivityMenu.classList.contains("open")) positionPrototypeActivityMenu();
  });

  // The current activity expands from its actual rendered position into a place.
  function setActivityOrigin() {
    const cardRect = homeActivityCards[homeActivityIndex].getBoundingClientRect();
    const screenRect = deviceScreen.getBoundingClientRect();
    const scale = screenRect.width / 430;
    activitySpace.style.setProperty("--activity-top", `${(cardRect.top - screenRect.top) / scale}px`);
    activitySpace.style.setProperty("--activity-left", `${(cardRect.left - screenRect.left) / scale}px`);
    activitySpace.style.setProperty("--activity-width", `${cardRect.width / scale}px`);
    activitySpace.style.setProperty("--activity-height", `${cardRect.height / scale}px`);
  }

  function enterActivity() {
    setActivityOrigin();
    closeProfile();
    deviceScreen.classList.remove("now-home");
    activitySpace.setAttribute("aria-hidden", "false");
    activitySpace.classList.add("preparing");
    homeView.classList.add("activity-entering");
    bottomSystem.classList.remove("hidden-for-activity");
    setPrototypeActive("activity");
    requestAnimationFrame(() => requestAnimationFrame(() => activitySpace.classList.add("active")));
    const activeTitle = $("h1", activityPageViews.find((view) => view.dataset.activityPageView === currentActivityPage));
    window.setTimeout(() => activeTitle.focus({ preventScroll: true }), 450);
  }

  function exitActivity() {
    setActivityOrigin();
    deviceScreen.classList.add("now-home");
    activitySpace.classList.remove("active");
    homeView.classList.remove("activity-entering");
    bottomSystem.classList.remove("hidden-for-activity");
    setPrototypeActive("now");
    window.setTimeout(() => {
      activitySpace.classList.remove("preparing");
      activitySpace.setAttribute("aria-hidden", "true");
      homeActivityCards[homeActivityIndex].focus({ preventScroll: true });
    }, 440);
  }

  currentActivity.addEventListener("pointerdown", (event) => {
    if (homeActivityPointerId !== null || (event.pointerType === "mouse" && event.button !== 0)) return;
    if (!event.target.closest(".current-activity-card.is-active")) return;
    homeActivityPointerId = event.pointerId;
    homeActivityDragStartX = event.clientX;
    homeActivityDragX = 0;
    homeActivityWasDragged = false;
    currentActivity.setPointerCapture(event.pointerId);
    currentActivity.classList.add("is-dragging");
  });

  currentActivity.addEventListener("pointermove", (event) => {
    if (event.pointerId !== homeActivityPointerId) return;
    homeActivityDragX = event.clientX - homeActivityDragStartX;
    if (Math.abs(homeActivityDragX) > 5) homeActivityWasDragged = true;
    const visualDistance = Math.max(-104, Math.min(104, homeActivityDragX));
    currentActivity.style.setProperty("--home-activity-drag", `${visualDistance}px`);
  });

  currentActivity.addEventListener("pointerup", (event) => finishHomeActivityDrag(event));
  currentActivity.addEventListener("pointercancel", (event) => finishHomeActivityDrag(event, { cancelled: true }));

  homeActivityCards.forEach((card) => {
    card.addEventListener("click", (event) => {
      if (suppressHomeActivityClick) {
        event.preventDefault();
        return;
      }
      openHomeActivityCard(card);
    });
    card.addEventListener("keydown", (event) => {
      if (event.key !== "ArrowLeft" && event.key !== "ArrowRight") return;
      event.preventDefault();
      moveHomeActivity(event.key === "ArrowRight" ? 1 : -1, { focus: true });
    });
  });
  spaceBack.addEventListener("click", exitActivity);

  function openTravelResultsDirect() {
    resetDiningExperience();
    resetTravelExperience();
    currentNowScene = "travel";
    prototypeNowItems.forEach((item) => item.setAttribute("aria-checked", String(item.dataset.nowScene === "travel")));
    closePrototypeNowMenu();
    selectRoute("now");
    setTravelState("results");
    travelResultsScroll.scrollTop = 0;
    window.setTimeout(() => travelResultsScroll.focus({ preventScroll: true }), 80);
  }

  function setNowScene(scene) {
    if (!prototypeNowItems.some((item) => item.dataset.nowScene === scene)) return;
    currentNowScene = scene;
    prototypeNowItems.forEach((item) => item.setAttribute("aria-checked", String(item.dataset.nowScene === scene)));
    closePrototypeNowMenu();
    resetDiningExperience();
    resetTravelExperience();
    navigatePrototype("now");
  }

  prototypeNowItems.forEach((item) => {
    item.addEventListener("click", () => setNowScene(item.dataset.nowScene));
  });

  prototypeActivityItems.forEach((item) => {
    item.addEventListener("click", () => {
      const matchingHomeIndex = homeActivityCards.findIndex((card) => card.dataset.activityPage === item.dataset.activityPage);
      if (matchingHomeIndex >= 0) {
        homeActivityIndex = matchingHomeIndex;
        updateHomeActivityCarousel({ syncActivity: false });
      }
      setActivityPage(item.dataset.activityPage, { focusTitle: true });
      closePrototypeActivityMenu();
      if (!activitySpace.classList.contains("active")) navigatePrototype("activity");
    });
  });

  document.addEventListener("pointerdown", (event) => {
    if (!prototypeNowMenu.contains(event.target) && !prototypeNowButton.contains(event.target)) closePrototypeNowMenu();
    if (!prototypeActivityMenu.contains(event.target) && !prototypeActivityButton.contains(event.target)) closePrototypeActivityMenu();
  });
  $(".dark-button", activitySpace).addEventListener("click", () => showToast("已恢复工作集，并定位到待定的转场方案。"));
  $$('[data-activity-card]', activitySpace).forEach((button) => {
    button.addEventListener("click", () => showToast(button.dataset.activityToast || "已在活动中打开内容。"));
  });
  const activityFilters = $$('[data-activity-filter]', activitySpace);
  activityFilters.forEach((button) => {
    button.addEventListener("click", () => {
      const filter = button.dataset.activityFilter;
      const page = button.closest(".activity-page");
      const pageFilters = $$('[data-activity-filter]', page);
      const pageItems = $$('[data-activity-kind]', page);
      const pageBoard = $(".activity-board, .shanghai-activity-board, .dinner-activity-board", page);
      pageFilters.forEach((item) => {
        const active = item === button;
        item.classList.toggle("active", active);
        item.setAttribute("aria-pressed", String(active));
      });
      pageItems.forEach((item) => {
        item.hidden = filter !== "all" && !item.dataset.activityKind.split(" ").includes(filter);
      });
      if (pageBoard) pageBoard.classList.toggle("filtered", filter !== "all");
    });
  });

  // Needs Attention expands where the decision already lives.
  $$(".attention-item").forEach((item) => {
    const summary = $(".attention-summary", item);
    const detail = $(".attention-detail", item);
    summary.addEventListener("click", () => {
      if (item.dataset.attention === "trip") {
        openTravelResultsDirect();
        return;
      }
      const shouldOpen = !item.classList.contains("expanded");
      $$(".attention-item.expanded").forEach((openItem) => {
        if (openItem !== item) {
          openItem.classList.remove("expanded");
          $(".attention-summary", openItem).setAttribute("aria-expanded", "false");
          $(".attention-detail", openItem).setAttribute("aria-hidden", "true");
        }
      });
      item.classList.toggle("expanded", shouldOpen);
      summary.setAttribute("aria-expanded", String(shouldOpen));
      detail.setAttribute("aria-hidden", String(!shouldOpen));
    });

    $$(".inline-actions button", item).forEach((button) => {
      button.addEventListener("click", () => {
        const action = button.dataset.action;
        if (action === "later") {
          item.classList.remove("expanded");
          summary.setAttribute("aria-expanded", "false");
          detail.setAttribute("aria-hidden", "true");
          showToast("已保留在原位，稍后处理。");
        } else if (action === "review") {
          showToast(item.dataset.attention === "trip" ? "机票对比已加入当前情境。" : "架构笔记已加入活动情境。");
        } else {
          showToast("已带着这项决策继续活动。");
        }
      });
    });
  });

  // Stable system locations are reached from the external Prototype Navigator.
  const secondaryView = $("#secondaryView");
  const secondaryTitle = $("#secondaryTitle");
  const spacesContent = $("#spacesContent");
  const libraryContent = $("#libraryContent");
  const libraryTopActions = $("#libraryTopActions");
  const libraryCreateButton = $("#libraryCreateButton");
  const librarySearchButton = $("#librarySearchButton");
  const libraryMoreButton = $("#libraryMoreButton");
  const collectionsMoreButton = $("#collectionsMoreButton");
  const collectionsView = $("#collectionsView");
  const collectionsViewScroll = $("#collectionsViewScroll");
  const collectionsBack = $("#collectionsBack");
  const collectionsSearch = $("#collectionsSearch");
  const musicLibraryView = $("#musicLibraryView");
  const musicLibraryScroll = $("#musicLibraryScroll");
  const musicBack = $("#musicBack");
  const musicRecord = $("#musicRecord");
  const musicRecordCover = $("#musicRecordCover");
  const musicTrackTitle = $("#musicTrackTitle");
  const musicTrackArtist = $("#musicTrackArtist");
  const musicPrevious = $("#musicPrevious");
  const musicPlay = $("#musicPlay");
  const musicNext = $("#musicNext");
  let baseRoute = "now";
  let musicTrackIndex = 0;
  let musicPlaying = true;

  const musicTracks = [
    { title: "BIRDS OF A FEATHER", artist: "Billie Eilish", cover: "assets/music/covers/hit-me-hard-and-soft.jpg" },
    { title: "Espresso", artist: "Sabrina Carpenter", cover: "assets/music/covers/espresso.jpg" },
    { title: "Blinding Lights", artist: "The Weeknd", cover: "assets/music/covers/after-hours.jpg" }
  ];

  function syncDiningPresentation(route = baseRoute) {
    const presented = route === "now" && currentNowScene === "dining" && !["idle", "query-processing"].includes(diningState);
    diningScene.classList.toggle("is-presented", presented);
    diningScene.setAttribute("aria-hidden", String(!presented));
    deviceScreen.classList.toggle("dining-scene-active", presented);
  }

  function syncTravelPresentation(route = baseRoute) {
    const presented = route === "now" && currentNowScene === "travel" && travelState === "results";
    travelScene.classList.toggle("is-presented", presented);
    travelScene.setAttribute("aria-hidden", String(!presented));
    deviceScreen.classList.toggle("travel-scene-active", presented);
  }

  function selectRoute(route) {
    if (calendarView.classList.contains("is-visible")) closeCalendar({ restoreFocus: false });
    hideCalendarLaunch();
    baseRoute = route;
    setPrototypeActive(route);
    deviceScreen.classList.toggle("now-home", route === "now");
    syncDiningPresentation(route);
    syncTravelPresentation(route);

    if (route === "now") {
      secondaryView.classList.remove("visible");
      secondaryView.setAttribute("aria-hidden", "true");
      libraryTopActions.hidden = true;
      return;
    }

    const showSpaces = route === "spaces";
    secondaryTitle.textContent = showSpaces ? "空间" : "库";
    spacesContent.hidden = !showSpaces;
    libraryContent.hidden = showSpaces;
    libraryTopActions.hidden = showSpaces;
    secondaryView.classList.add("visible");
    secondaryView.setAttribute("aria-hidden", "false");
    $(".secondary-view-scroll").scrollTop = 0;
  }

  $$(".route-content > button").forEach((button) => button.addEventListener("click", () => showToast(`${$("strong", button).textContent} 会保留在这个固定位置。`)));

  function showCalendarLaunch() {
    if (baseRoute !== "now" || calendarView.classList.contains("is-visible")) return;
    calendarLaunchPill.classList.add("is-visible");
    calendarLaunchPill.setAttribute("aria-hidden", "false");
    calendarLaunchPill.tabIndex = 0;
    homeDateTrigger.setAttribute("aria-expanded", "true");
  }

  function hideCalendarLaunch() {
    calendarLaunchPill.classList.remove("is-visible");
    calendarLaunchPill.setAttribute("aria-hidden", "true");
    calendarLaunchPill.tabIndex = -1;
    homeDateTrigger.setAttribute("aria-expanded", "false");
  }

  function openCalendar() {
    hideCalendarLaunch();
    calendarView.classList.add("is-visible");
    calendarView.setAttribute("aria-hidden", "false");
    deviceScreen.classList.add("calendar-active");
    bottomSystem.classList.add("hidden-for-activity");
    calendarViewScroll.scrollTop = 0;
    window.setTimeout(() => calendarBack.focus({ preventScroll: true }), 260);
  }

  function closeCalendar({ restoreFocus = true } = {}) {
    calendarView.classList.remove("is-visible");
    calendarView.setAttribute("aria-hidden", "true");
    deviceScreen.classList.remove("calendar-active");
    bottomSystem.classList.remove("hidden-for-activity");
    if (restoreFocus) window.setTimeout(() => homeDateTrigger.focus({ preventScroll: true }), 180);
  }

  homeDateTrigger.addEventListener("click", () => {
    if (calendarLaunchPill.classList.contains("is-visible")) hideCalendarLaunch();
    else showCalendarLaunch();
  });
  calendarLaunchPill.addEventListener("click", openCalendar);
  calendarBack.addEventListener("click", () => closeCalendar());
  calendarModeButtons.forEach((button) => {
    button.addEventListener("click", () => {
      calendarModeButtons.forEach((item) => {
        const selected = item === button;
        item.classList.toggle("is-selected", selected);
        item.setAttribute("aria-selected", String(selected));
      });
    });
  });

  // Library objects remain inspectable: presentation, source relationships, and AI-created grouping are separate layers.
  const objectDetailView = $("#objectDetailView");
  const galleryDetailView = $("#galleryDetailView");
  const libraryLensView = $("#libraryLensView");
  const deepLibraryViews = [objectDetailView, galleryDetailView, libraryLensView];
  const myJournalGalleryCard = $("#myJournalGalleryCard");
  const myJournalGalleryObject = $("#myJournalGalleryObject");
  const journalReaderView = $("#journalReaderView");
  const journalReadablePage = $("#journalReadablePage");
  const journalReaderScroll = $("#journalReaderScroll");
  const journalReaderBack = $("#journalReaderBack");
  const journalReaderSearch = $("#journalReaderSearch");
  const journalReaderEdit = $("#journalReaderEdit");
  const journalPrevious = $("#journalPrevious");
  const journalNext = $("#journalNext");
  const journalPosition = $("#journalPosition");
  const journalJumpPanel = $("#journalJumpPanel");
  const journalSearchLayer = $("#journalSearchLayer");
  const journalSearchInput = $("#journalSearchInput");
  const journalSearchCancel = $("#journalSearchCancel");
  const journalSearchResults = $("#journalSearchResults");
  const journalOpenShared = $("#journalOpenShared");
  const readerAddContent = $("#readerAddContent");
  const readerDeleteSelection = $("#readerDeleteSelection");
  const readerDates = ["8 月 24 日", "8 月 17 日", "8 月 12 日", "7 月 28 日"];
  let journalReaderIndex = 0;
  let journalOpenAnimation;

  const objectExamples = {
    "interface-sketch": {
      title: "AIOS Interface Sketch",
      preview: "assets/previews/interface-architecture.svg",
      alt: "AIOS 界面草图",
      caption: "界面架构 · 画板 04"
    },
    "architecture-notes": {
      title: "Architecture Notes",
      preview: "assets/previews/object-model.svg",
      alt: "AIOS 架构笔记",
      caption: "系统模型 · 今天编辑"
    },
    "tokyo-photo": {
      title: "IMG_5821",
      preview: "assets/gallery/tokyo-memories.png",
      alt: "东京旅行照片和纪念物",
      caption: "照片 · 今天收到"
    }
  };

  const collectionExamples = {
    wardrobe: {
      title: "穿搭",
      asset: "assets/gallery/outfit-cabinet.png",
      alt: "穿搭合集",
      summary: "46 套穿搭 · 68 个来源对象",
      count: "68 个对象",
      reason: "根据完整穿搭组合，整理自你确认保留的照片与购买记录。",
      sources: [["photo", "穿搭照片", "已收录 46 项", "已收录"], ["doc.text", "购买记录", "已收录 17 项", "已收录"], ["sparkles", "搭配笔记", "AI 建议 5 项", "建议"]]
    },
    tokyo: {
      title: "旅行手账",
      asset: "assets/gallery/tokyo-memories.png",
      alt: "旅行手账合集",
      summary: "84 个对象 · 2025 年 4 月",
      count: "84 个对象",
      reason: "收集自你的东京活动，并按旅程顺序整理成手账。",
      sources: [["photo", "照片", "已收录 62 项", "已收录"], ["doc.text", "票据与行程", "已收录 13 项", "已收录"], ["sparkles", "地图与收藏地点", "AI 建议 9 项", "建议"]]
    },
    archive: {
      title: "票据夹",
      asset: "assets/gallery/aios-archive.png",
      alt: "票据夹合集",
      summary: "63 个对象",
      count: "63 个对象",
      reason: "整理自已保存的票据、文档和相关记录。",
      sources: [["square.grid.2x2", "票据", "已收录 24 项", "已收录"], ["doc.text", "文档与笔记", "已收录 31 项", "已收录"], ["sparkles", "关联内容", "AI 建议 8 项", "建议"]]
    }
  };

  function closeLibraryDetails({ restoreNavigation = true } = {}) {
    deepLibraryViews.forEach((view) => {
      view.classList.remove("visible");
      view.setAttribute("aria-hidden", "true");
    });
    if (restoreNavigation) {
      bottomSystem.classList.remove("hidden-for-activity");
      setPrototypeActive(baseRoute === "library" ? "library" : baseRoute);
    }
  }

  function openCollectionsView() {
    closeLibraryDetails({ restoreNavigation: false });
    closeMusicLibrary({ restoreNavigation: false });
    selectRoute("library");
    collectionsView.classList.add("visible");
    collectionsView.setAttribute("aria-hidden", "false");
    collectionsViewScroll.scrollTop = 0;
    bottomSystem.classList.remove("hidden-for-activity", "journal-context");
    setPrototypeActive("gallery");
  }

  function closeCollectionsView({ restoreNavigation = true } = {}) {
    collectionsView.classList.remove("visible");
    collectionsView.setAttribute("aria-hidden", "true");
    if (restoreNavigation) setPrototypeActive("library");
  }

  function setMusicPlayback(playing) {
    musicPlaying = playing;
    musicRecord.classList.toggle("is-playing", musicPlaying);
    musicPlay.classList.toggle("is-paused", !musicPlaying);
    musicPlay.setAttribute("aria-pressed", String(musicPlaying));
    musicPlay.setAttribute("aria-label", musicPlaying ? "暂停" : "播放");
  }

  function renderMusicTrack(index) {
    musicTrackIndex = (index + musicTracks.length) % musicTracks.length;
    const track = musicTracks[musicTrackIndex];
    musicRecordCover.src = track.cover;
    musicTrackTitle.textContent = track.title;
    musicTrackArtist.textContent = track.artist;
    musicRecord.animate(
      [{ opacity: 0.72 }, { opacity: 1 }],
      { duration: 220, easing: "ease-out" }
    );
  }

  function openMusicLibrary() {
    closeCollectionsView({ restoreNavigation: false });
    closeLibraryDetails({ restoreNavigation: false });
    selectRoute("library");
    musicLibraryView.classList.add("visible");
    musicLibraryView.setAttribute("aria-hidden", "false");
    musicLibraryScroll.scrollTop = 0;
    bottomSystem.classList.remove("hidden-for-activity", "journal-context");
    setPrototypeActive("music");
  }

  function closeMusicLibrary({ restoreNavigation = true } = {}) {
    musicLibraryView.classList.remove("visible");
    musicLibraryView.setAttribute("aria-hidden", "true");
    if (restoreNavigation) setPrototypeActive("library");
  }

  function setReaderEditing(editing) {
    journalReaderView.classList.toggle("is-editing", editing);
    journalReaderEdit.setAttribute("aria-pressed", String(editing));
    journalReaderEdit.setAttribute("aria-label", editing ? "完成编辑" : "编辑当前日记");
    $("img", journalReaderEdit).src = `assets/icons/sf-symbols/${editing ? "checkmark" : "pencil"}.png`;
    $$(".reader-entry-copy", journalReaderView).forEach((copy) => {
      copy.contentEditable = editing && !copy.closest("[hidden]") ? "true" : "false";
    });
    if (!editing) $$("[data-edit-visual].selected", journalReaderView).forEach((visual) => visual.classList.remove("selected"));
    readerDeleteSelection.disabled = true;
  }

  function closeJournalJump() {
    journalJumpPanel.classList.remove("visible");
    journalJumpPanel.setAttribute("aria-hidden", "true");
    journalPosition.setAttribute("aria-expanded", "false");
  }

  function setJournalReaderEntry(index) {
    journalReaderIndex = Math.max(0, Math.min(readerDates.length - 1, index));
    journalReaderView.dataset.entry = String(journalReaderIndex);
    $$('[data-reader-entry]', journalReaderView).forEach((panel) => {
      panel.hidden = Number(panel.dataset.readerEntry) !== journalReaderIndex;
    });
    journalPosition.textContent = readerDates[journalReaderIndex];
    journalPrevious.disabled = journalReaderIndex === readerDates.length - 1;
    journalNext.disabled = journalReaderIndex === 0;
    journalReaderScroll.scrollTop = 0;
    closeJournalJump();
    setReaderEditing(false);
  }

  function closeJournalSearch({ restorePrototype = true } = {}) {
    journalSearchLayer.classList.remove("visible");
    journalSearchLayer.setAttribute("aria-hidden", "true");
    journalSearchInput.value = "";
    journalSearchResults.classList.add("is-empty");
    $$("button", journalSearchResults).forEach((button) => (button.hidden = false));
    if (restorePrototype && journalReaderView.classList.contains("visible")) setPrototypeActive("journal-open");
  }

  function openJournalSearch({ preset = "" } = {}) {
    closeJournalJump();
    setReaderEditing(false);
    journalSearchLayer.classList.add("visible");
    journalSearchLayer.setAttribute("aria-hidden", "false");
    journalSearchInput.value = preset;
    journalSearchInput.dispatchEvent(new Event("input"));
    setPrototypeActive("journal-search");
    window.setTimeout(() => journalSearchInput.focus({ preventScroll: true }), 180);
  }

  async function openJournalReader({ entry = 0, animateFromGallery = true, search = false } = {}) {
    const sourceRect = animateFromGallery ? myJournalGalleryObject.getBoundingClientRect() : null;
    journalOpenAnimation?.cancel();
    closeCollectionsView({ restoreNavigation: false });
    closeLibraryDetails({ restoreNavigation: false });
    selectRoute("library");
    setJournalReaderEntry(entry);
    closeJournalSearch({ restorePrototype: false });
    journalReaderView.classList.toggle("is-opening", Boolean(sourceRect));
    journalReaderView.classList.add("visible");
    journalReaderView.setAttribute("aria-hidden", "false");
    bottomSystem.classList.add("journal-context");
    setPrototypeActive(search ? "journal-search" : "journal-open");

    if (sourceRect) {
      const screenRect = deviceScreen.getBoundingClientRect();
      const canvasScale = screenRect.width / 430;
      const left = (sourceRect.left - screenRect.left) / canvasScale;
      const top = (sourceRect.top - screenRect.top) / canvasScale;
      const width = sourceRect.width / canvasScale;
      const height = sourceRect.height / canvasScale;
      const destination = { left: 113, top: 177, width: 204 };
      journalOpenShared.style.left = `${left}px`;
      journalOpenShared.style.top = `${top}px`;
      journalOpenShared.style.width = `${width}px`;
      journalOpenShared.style.height = `${height}px`;
      journalOpenShared.classList.add("visible");
      myJournalGalleryCard.classList.add("is-opening-target");
      await nextPaint();
      const destinationScale = destination.width / width;
      const finalTransform = `translate3d(${destination.left - left}px, ${destination.top - top}px, 0) scale(${destinationScale})`;
      journalOpenAnimation = journalOpenShared.animate([
        { transform: "translate3d(0, 0, 0) scale(1)", opacity: 1 },
        { transform: finalTransform, opacity: 1, offset: 0.72 },
        { transform: finalTransform, opacity: 0 }
      ], { duration: 520, easing: "cubic-bezier(0.2, 0.78, 0.2, 1)", fill: "forwards" });
      window.setTimeout(() => journalReaderView.classList.remove("is-opening"), 210);
      await journalOpenAnimation.finished.catch(() => undefined);
      journalOpenShared.classList.remove("visible");
      journalOpenShared.removeAttribute("style");
      myJournalGalleryCard.classList.remove("is-opening-target");
    } else {
      journalReaderView.classList.remove("is-opening");
    }

    if (search) openJournalSearch({ preset: "雨停以后" });
  }

  function closeJournalReader({ restoreNavigation = true } = {}) {
    journalOpenAnimation?.cancel();
    journalOpenAnimation = undefined;
    journalOpenShared.classList.remove("visible");
    journalOpenShared.removeAttribute("style");
    myJournalGalleryCard.classList.remove("is-opening-target");
    closeJournalSearch({ restorePrototype: false });
    closeJournalJump();
    setReaderEditing(false);
    journalReaderView.classList.remove("visible", "is-opening");
    journalReaderView.setAttribute("aria-hidden", "true");
    bottomSystem.classList.remove("journal-context");
    if (restoreNavigation) setPrototypeActive("library");
  }

  function showLibraryDetail(view, prototypeState) {
    closeLibraryDetails({ restoreNavigation: false });
    view.classList.add("visible");
    view.setAttribute("aria-hidden", "false");
    $(".detail-scroll", view).scrollTop = 0;
    bottomSystem.classList.add("hidden-for-activity");
    setPrototypeActive(prototypeState);
  }

  function openObjectDetail(id = "interface-sketch") {
    const object = objectExamples[id] || objectExamples["interface-sketch"];
    $("#objectDetailTitle").textContent = object.title;
    const preview = $("#objectDetailPreview");
    preview.src = object.preview;
    preview.alt = object.alt;
    $(".object-canvas figcaption").textContent = object.caption;
    showLibraryDetail(objectDetailView, "object");
  }

  function renderCollectionSources(sources) {
    $("#collectionSources").innerHTML = sources.map(([icon, name, detail, state]) => `
      <div><img src="assets/icons/sf-symbols/${icon}.png" alt=""><span><strong>${name}</strong><small>${detail}</small></span><b class="${state === "建议" ? "suggested" : ""}">${state}</b></div>
    `).join("");
  }

  function openGalleryDetail(id = "wardrobe") {
    const collection = collectionExamples[id] || collectionExamples.wardrobe;
    const asset = $("#collectionAsset");
    asset.src = collection.asset;
    asset.alt = collection.alt;
    $("#collectionTitle").textContent = collection.title;
    $("#collectionSummary").textContent = collection.summary;
    $("#collectionCount").textContent = collection.count;
    $("#collectionReason").textContent = collection.reason;
    renderCollectionSources(collection.sources);
    showLibraryDetail(galleryDetailView, "gallery");
  }

  const lensCopy = {
    context: ["情境", "通过对象所在的空间和活动找到它们。"],
    time: ["时间", "按时间返回，即使你只记得大概时间。"],
    type: ["类型", "按内容含义浏览，而不是按文件扩展名。"],
    people: ["人物", "查看你与某人共享的对象和活动。"]
  };

  function openLens(id) {
    const [title, description] = lensCopy[id] || lensCopy.context;
    $("#lensTitle").textContent = title;
    $("#lensDescription").textContent = description;
    $$("[data-lens-panel]").forEach((panel) => (panel.hidden = panel.dataset.lensPanel !== id));
    showLibraryDetail(libraryLensView, "library");
  }

  $("#objectBack").addEventListener("click", () => closeLibraryDetails());
  $("#galleryBack").addEventListener("click", () => closeLibraryDetails());
  $("#lensBack").addEventListener("click", () => closeLibraryDetails());
  $$("[data-object-open]").forEach((button) => button.addEventListener("click", () => openObjectDetail(button.dataset.objectOpen)));
  $$("[data-gallery]").forEach((button) => button.addEventListener("click", () => {
    if (button.dataset.gallery === "journal") openJournalReader();
    else openGalleryDetail(button.dataset.gallery);
  }));
  $("#recentJournal").addEventListener("click", () => openJournalReader({ animateFromGallery: false }));
  $$("[data-lens]").forEach((button) => button.addEventListener("click", () => openLens(button.dataset.lens)));
  $("#openMusicCollection").addEventListener("click", openMusicLibrary);
  collectionsMoreButton.addEventListener("click", openCollectionsView);
  libraryMoreButton.addEventListener("click", openCollectionsView);
  collectionsBack.addEventListener("click", () => closeCollectionsView());
  $$('[data-collection-open]', collectionsView).forEach((button) => button.addEventListener("click", () => {
    const collection = button.dataset.collectionOpen;
    closeCollectionsView({ restoreNavigation: false });
    if (collection === "journal") openJournalReader({ animateFromGallery: false });
    else if (collection === "music") openMusicLibrary();
    else openGalleryDetail(collection);
  }));
  musicBack.addEventListener("click", () => closeMusicLibrary());
  musicPrevious.addEventListener("click", () => renderMusicTrack(musicTrackIndex - 1));
  musicNext.addEventListener("click", () => renderMusicTrack(musicTrackIndex + 1));
  musicPlay.addEventListener("click", () => setMusicPlayback(!musicPlaying));

  function enableMouseDragScroll(scroller) {
    if (!scroller) return;
    let pointerId = null;
    let startX = 0;
    let startScrollLeft = 0;
    let moved = false;
    let suppressClick = false;

    scroller.addEventListener("pointerdown", (event) => {
      if (event.pointerType !== "mouse" || event.button !== 0) return;
      pointerId = event.pointerId;
      startX = event.clientX;
      startScrollLeft = scroller.scrollLeft;
      moved = false;
      scroller.setPointerCapture(pointerId);
    });

    scroller.addEventListener("pointermove", (event) => {
      if (event.pointerId !== pointerId) return;
      const distance = event.clientX - startX;
      if (!moved && Math.abs(distance) > 4) {
        moved = true;
        scroller.classList.add("is-pointer-dragging");
      }
      if (!moved) return;
      event.preventDefault();
      scroller.scrollLeft = startScrollLeft - distance;
    });

    const finish = (event) => {
      if (event.pointerId !== pointerId) return;
      suppressClick = moved;
      try { scroller.releasePointerCapture(pointerId); } catch (_) { /* pointer already released */ }
      pointerId = null;
      moved = false;
      scroller.classList.remove("is-pointer-dragging");
      window.setTimeout(() => { suppressClick = false; }, 0);
    };

    scroller.addEventListener("pointerup", finish);
    scroller.addEventListener("pointercancel", finish);
    scroller.addEventListener("click", (event) => {
      if (!suppressClick) return;
      event.preventDefault();
      event.stopPropagation();
      suppressClick = false;
    }, true);
  }

  function enableWheelHorizontalScroll(scroller) {
    if (!scroller) return;
    scroller.addEventListener("wheel", (event) => {
      if (Math.abs(event.deltaY) <= Math.abs(event.deltaX)) return;
      const maxScrollLeft = scroller.scrollWidth - scroller.clientWidth;
      if (maxScrollLeft <= 0) return;
      const nextScrollLeft = Math.max(
        0,
        Math.min(maxScrollLeft, scroller.scrollLeft + event.deltaY)
      );
      if (nextScrollLeft === scroller.scrollLeft) return;
      event.preventDefault();
      scroller.scrollLeft = nextScrollLeft;
    }, { passive: false });
  }

  enableMouseDragScroll($("#galleryRail"));
  enableMouseDragScroll($(".music-collections-rail"));
  enableWheelHorizontalScroll($("#galleryRail"));

  journalReaderBack.addEventListener("click", () => closeJournalReader());
  journalReaderSearch.addEventListener("click", () => openJournalSearch());
  journalReaderEdit.addEventListener("click", () => setReaderEditing(!journalReaderView.classList.contains("is-editing")));
  journalPrevious.addEventListener("click", () => setJournalReaderEntry(journalReaderIndex + 1));
  journalNext.addEventListener("click", () => setJournalReaderEntry(journalReaderIndex - 1));
  journalPosition.addEventListener("click", () => {
    const open = !journalJumpPanel.classList.contains("visible");
    journalJumpPanel.classList.toggle("visible", open);
    journalJumpPanel.setAttribute("aria-hidden", String(!open));
    journalPosition.setAttribute("aria-expanded", String(open));
  });
  $$("[data-jump-entry]", journalJumpPanel).forEach((button) => button.addEventListener("click", () => setJournalReaderEntry(Number(button.dataset.jumpEntry))));
  journalSearchCancel.addEventListener("click", () => closeJournalSearch());
  journalSearchInput.addEventListener("input", () => {
    const query = journalSearchInput.value.trim().toLowerCase();
    const keywords = [
      "今天 方案 讲完 手记 日记 雨停 雨停以后 街道",
      "方案册 浅蓝灰 笔记本 notebook",
      "折叠伞 雨伞 伞 雨",
      "8月17日 8 月 17 日 8月17日日记 日记 迪士尼 去迪士尼 城堡 白天 晴天 游玩 游玩记录 当天相关照片 照片",
      "8月17日 8 月 17 日 迪士尼 冰饮 饮料 杯子 柠檬 中午 休息 Personal Object",
      "8月17日 8 月 17 日 迪士尼 城堡 烟花 夜晚 天黑 当天相关照片 照片"
    ];
    let matches = 0;
    $$("button", journalSearchResults).forEach((button, index) => {
      const match = Boolean(query) && `${button.textContent} ${keywords[index]}`.toLowerCase().includes(query);
      button.hidden = !match;
      if (match) matches += 1;
    });
    journalSearchResults.classList.toggle("is-empty", matches === 0);
  });
  $$("[data-search-result]", journalSearchResults).forEach((button) => button.addEventListener("click", () => {
    setJournalReaderEntry(Number(button.dataset.searchResult));
    closeJournalSearch();
  }));
  $$("[data-edit-visual]", journalReaderView).forEach((visual) => visual.addEventListener("click", () => {
    if (!journalReaderView.classList.contains("is-editing")) return;
    $$("[data-edit-visual].selected", journalReaderView).forEach((selected) => selected.classList.remove("selected"));
    visual.classList.add("selected");
    readerDeleteSelection.disabled = false;
  }));
  readerDeleteSelection.addEventListener("click", () => {
    const selectedVisual = $("[data-edit-visual].selected", journalReaderView);
    if (!selectedVisual) return;
    selectedVisual.hidden = true;
    selectedVisual.classList.remove("selected");
    readerDeleteSelection.disabled = true;
  });
  readerAddContent.addEventListener("click", () => {
    const activePanel = $(`[data-reader-entry="${journalReaderIndex}"]`, journalReaderView);
    const hiddenVisual = $("[data-edit-visual][hidden]", activePanel);
    if (hiddenVisual) {
      hiddenVisual.hidden = false;
      hiddenVisual.classList.add("selected");
      readerDeleteSelection.disabled = false;
      return;
    }
    const copy = $(".reader-entry-copy", activePanel);
    if (!copy) return;
    const paragraph = document.createElement("p");
    paragraph.innerHTML = "<br>";
    copy.append(paragraph);
    copy.contentEditable = "true";
    copy.focus({ preventScroll: true });
  });

  $$(".object-capabilities button").forEach((button) => button.addEventListener("click", () => showToast(`可以对这个对象执行“${button.textContent.trim()}”。`)));
  $$(".relation-path, .related-objects > button").forEach((button) => button.addEventListener("click", () => showToast("已打开关联内容，仍停留在当前对象。")));
  $$("[data-collection-action]").forEach((button) => {
    button.addEventListener("click", () => {
      const messages = { rename: "合集名称已可编辑。", adjust: "现在可以调整收录对象和呈现方式。", unpin: "已取消固定，合集和原始对象仍会保留。", objects: "正在显示此合集中的所有原始对象。" };
      showToast(messages[button.dataset.collectionAction]);
    });
  });
  $(".review-inclusion").addEventListener("click", () => showToast("可以查看已收录、未收录和 AI 建议的对象。"));
  $("#deleteCollection").addEventListener("click", () => showToast("合集已从预览中删除，原始对象仍保留在库中。"));

  // Search and profile are small system layers rather than destination apps.
  const searchButton = $("#searchButton");
  const searchLayer = $("#searchLayer");
  const searchInput = $("#searchInput");
  const searchCancel = $("#searchCancel");
  const clearSearch = $("#clearSearch");
  const profileButton = $("#profileButton");
  const profilePopover = $("#profilePopover");
  const layerScrim = $("#layerScrim");

  function openSearch() {
    closeProfile();
    searchLayer.classList.add("visible");
    searchLayer.setAttribute("aria-hidden", "false");
    window.setTimeout(() => searchInput.focus(), 220);
  }

  function closeSearch() {
    searchLayer.classList.remove("visible");
    searchLayer.setAttribute("aria-hidden", "true");
    searchInput.value = "";
    $$(".search-content > button").forEach((button) => (button.hidden = false));
  }

  function openProfile() {
    profilePopover.classList.add("visible");
    profilePopover.setAttribute("aria-hidden", "false");
    layerScrim.classList.add("visible");
  }

  function closeProfile() {
    profilePopover.classList.remove("visible");
    profilePopover.setAttribute("aria-hidden", "true");
    if (!$("#commandLayer").classList.contains("visible") && !$("#proposalLayer").classList.contains("visible")) layerScrim.classList.remove("visible");
  }

  searchButton?.addEventListener("click", openSearch);
  librarySearchButton.addEventListener("click", openSearch);
  collectionsSearch.addEventListener("click", openSearch);
  searchCancel.addEventListener("click", closeSearch);
  clearSearch.addEventListener("click", () => {
    searchInput.value = "";
    searchInput.dispatchEvent(new Event("input"));
    searchInput.focus();
  });
  searchInput.addEventListener("input", () => {
    const query = searchInput.value.trim().toLowerCase();
    $$(".search-content > button").forEach((button) => {
      button.hidden = Boolean(query) && !button.textContent.toLowerCase().includes(query);
    });
  });
  profileButton?.addEventListener("click", () => profilePopover.classList.contains("visible") ? closeProfile() : openProfile());
  $$(".profile-popover > button").forEach((button) => button.addEventListener("click", () => showToast(button.textContent.trim())));

  // AI is a dismissible command layer with at most three contextual suggestions.
  const homeVoice = $("#homeVoice");
  const commandTrigger = $("#commandTrigger");
  const homeVoiceResumeLabel = $("#homeVoiceResumeLabel");
  const aiLiveButton = $("#aiLiveButton");
  const voiceTaskPanel = $("#voiceTaskPanel");
  const voiceTaskQuestion = $("#voiceTaskQuestion");
  const voiceTaskClose = $("#voiceTaskClose");
  const voiceTaskStatus = $("#voiceTaskStatus");
  const homeContextPanel = $("#homeContextPanel");
  const homeContextClose = $("#homeContextClose");
  const homeContextStatus = $("#homeContextStatus");
  const homeContextAnswer = $("#homeContextAnswer");
  const diningFollowupPanel = $("#diningFollowupPanel");
  const diningFollowupClose = $("#diningFollowupClose");
  const diningFollowupStatus = $("#diningFollowupStatus");
  const diningFollowupAnswer = $("#diningFollowupAnswer");
  const diningDishEntities = $$(".dining-dish-entity", diningFollowupPanel);
  const diningEntityActions = $("#diningEntityActions");
  const diningFavoriteAction = $("#diningFavoriteAction");
  const diningCartAction = $("#diningCartAction");
  const diningTastePanel = $("#diningTastePanel");
  const diningTasteClose = $("#diningTasteClose");
  const diningHistoryToggle = $("#diningHistoryToggle");
  const diningTasteStatus = $("#diningTasteStatus");
  const diningTasteAnswer = $("#diningTasteAnswer");
  const diningConversationHistory = $("#diningConversationHistory");
  const aiPrivateSurface = $("#aiPrivateSurface");
  const aiCollabSurface = $("#aiCollabSurface");
  const privateSpaceBack = $("#privateSpaceBack");
  const privateChatThread = $("#privateChatThread");
  const privateChatUser = $("#privateChatUser");
  const privateChatAssistant = $("#privateChatAssistant");
  const privateLiveControls = $("#privateLiveControls");
  const privateLiveMute = $("#privateLiveMute");
  const privateLiveMuteIcon = $("#privateLiveMuteIcon");
  const privateLiveVideo = $("#privateLiveVideo");
  const privateLiveVideoIcon = $("#privateLiveVideoIcon");
  const privateLiveEnd = $("#privateLiveEnd");
  const privateNoteFlow = $("#privateNoteFlow");
  const privateNoteCard = $("#privateNoteCard");
  const privateNoteStatus = $("#privateNoteStatus");
  const privateNoteActions = $("#privateNoteActions");
  const privateNoteDestroy = $("#privateNoteDestroy");
  const privateNoteTransfer = $("#privateNoteTransfer");
  const privateNoteReader = $("#privateNoteReader");
  const privateNoteDocument = $("#privateNoteDocument");
  const privateNoteBack = $("#privateNoteBack");
  const privateNoteViewDocument = $("#privateNoteViewDocument");
  const privateNoteViewStack = $("#privateNoteViewStack");
  const privateNoteStackView = $("#privateNoteStackView");
  const privateNoteShareButton = $("#privateNoteShareButton");
  const privateNoteShareLayer = $("#privateNoteShareLayer");
  const privateNoteShareBackdrop = $("#privateNoteShareBackdrop");
  const privateNoteSharePeople = $$("[data-private-share-person]", privateNoteShareLayer);
  const privateNoteShareCollections = $$("[data-private-share-collection]", privateNoteShareLayer);
  const privateNoteCardCarousel = $("#privateNoteCardCarousel");
  const privateNoteCardCopyScroll = $("#privateNoteCardCopyScroll");
  const privateNoteCardCopyText = $("#privateNoteCardCopyText");
  const privateNoteImageCards = $$(".private-note-image-card", privateNoteStackView);
  const aiLiveView = $("#aiLiveView");
  const aiLiveSelfView = $("#aiLiveSelfView");
  const liveMuteButton = $("#liveMuteButton");
  const liveMuteSymbol = $("#liveMuteSymbol");
  const liveVideoButton = $("#liveVideoButton");
  const liveVideoSymbol = $("#liveVideoSymbol");
  const liveEndButton = $("#liveEndButton");
  const memoryFlow = $("#memoryFlow");
  const memoryCard = $("#memoryCard");
  const memoryGenerating = $("#memoryGenerating");
  const memoryLines = $("#memoryLines");
  const memoryStop = $("#memoryStop");
  const journalDocument = $("#journalDocument");
  const journalScroll = $("#journalScroll");
  const journalActions = $("#journalActions");
  const journalSave = $("#journalSave");
  const journalDelete = $("#journalDelete");
  const journalDeleteConfirm = $("#journalDeleteConfirm");
  const journalDeleteCancel = $("#journalDeleteCancel");
  const journalDeleteConfirmButton = $("#journalDeleteConfirmButton");
  const filingEntryAbstract = $(".filing-entry-abstract");
  const filingBookFlight = $("#filingBookFlight");
  const filingBookStage = $("#filingBookStage");
  const filingLeftPage = $(".filing-left-page");
  const filingClosedAsset = $("#filingClosedAsset");
  const commandLayer = $("#commandLayer");
  const commandInput = $("#commandInput");
  const closeCommandButton = $("#closeCommand");
  const commandForm = $("#commandForm");
  const commandSuggestions = $("#commandSuggestions");
  const commandResult = $("#commandResult");
  const voiceHoldDelay = 320;
  let voiceHoldTimer = 0;
  let voicePointerId = null;
  let voiceDragStartX = 0;
  let voiceDragProgress = 0;
  let voiceDragDirection = "center";
  let voiceHoldActive = false;
  let suppressNextCommandClick = false;
  let suppressCommandClickTimer = 0;
  let voiceTaskTimers = [];
  let voiceTaskRunToken = 0;
  let activeVoiceTask = "";
  let homeContextTimers = [];
  let diningFollowupTimers = [];
  let diningTasteTimers = [];
  let diningResumeCompactTimer = 0;
  let resumableDiningAnswer = "";
  let selectedDiningDish = "";

  function suppressCommandClickTemporarily() {
    window.clearTimeout(suppressCommandClickTimer);
    suppressNextCommandClick = true;
    suppressCommandClickTimer = window.setTimeout(() => {
      suppressNextCommandClick = false;
    }, 700);
  }

  function clearVoiceTaskTimers() {
    voiceTaskTimers.forEach((timer) => window.clearTimeout(timer));
    voiceTaskTimers = [];
  }

  function showVoiceTaskStatus(text, { initial = false } = {}) {
    if (initial) {
      voiceTaskStatus.textContent = text;
      voiceTaskStatus.classList.remove("is-changing");
      requestAnimationFrame(() => voiceTaskStatus.classList.add("is-visible"));
      return;
    }
    voiceTaskStatus.classList.add("is-changing");
    voiceTaskTimers.push(window.setTimeout(() => {
      voiceTaskStatus.textContent = text;
      voiceTaskStatus.classList.remove("is-changing");
      voiceTaskStatus.classList.add("is-visible");
    }, 170));
  }

  function closeVoiceTaskProcessor({ immediate = false } = {}) {
    clearVoiceTaskTimers();
    voiceTaskRunToken += 1;
    if (immediate) homeVoice.style.transition = "none";
    homeVoice.classList.remove("is-voice-task", "is-task-completing");
    bottomSystem.classList.remove("voice-task-active");
    voiceTaskPanel.setAttribute("aria-hidden", "true");
    voiceTaskStatus.classList.remove("is-visible", "is-changing");
    voiceTaskStatus.textContent = "";
    activeVoiceTask = "";
    delete homeVoice.dataset.voiceTask;
    if (immediate) requestAnimationFrame(() => homeVoice.style.removeProperty("transition"));
  }

  function cancelVoiceTaskProcessor({ immediate = false } = {}) {
    const cancelledTask = activeVoiceTask;
    closeVoiceTaskProcessor({ immediate });
    if (cancelledTask === "dining") {
      clearDiningTimers();
      diningRunToken += 1;
      setDiningState("idle");
    } else if (cancelledTask === "travel") {
      clearTravelTimers();
      travelRunToken += 1;
      setTravelState("idle");
    }
  }

  function revealSceneFromVoice(scene, showResults, focusResults) {
    scene.classList.add("is-opening-from-voice");
    deviceScreen.classList.add("voice-scene-opening");
    showResults();
    window.setTimeout(() => {
      scene.classList.remove("is-opening-from-voice");
      deviceScreen.classList.remove("voice-scene-opening");
      focusResults?.();
    }, 580);
  }

  function runVoiceTaskProcessor({ kind, question, steps, delays, duration, onComplete }) {
    clearVoiceTaskTimers();
    const runToken = ++voiceTaskRunToken;
    activeVoiceTask = kind;
    homeVoice.dataset.voiceTask = kind;
    voiceTaskQuestion.textContent = question;
    voiceTaskStatus.textContent = "";
    voiceTaskStatus.classList.remove("is-visible", "is-changing");
    voiceTaskPanel.setAttribute("aria-hidden", "false");
    bottomSystem.classList.add("voice-task-active");
    homeVoice.classList.remove("is-task-completing");
    homeVoice.classList.add("is-voice-task");

    steps.forEach((step, index) => {
      voiceTaskTimers.push(window.setTimeout(() => {
        if (runToken !== voiceTaskRunToken) return;
        showVoiceTaskStatus(step, { initial: index === 0 });
      }, delays[index]));
    });

    voiceTaskTimers.push(window.setTimeout(() => {
      if (runToken !== voiceTaskRunToken) return;
      homeVoice.classList.add("is-task-completing");
      onComplete();
      window.setTimeout(() => {
        if (runToken === voiceTaskRunToken) closeVoiceTaskProcessor();
      }, 180);
    }, duration));
  }

  function clearDiningTimers() {
    diningTimers.forEach((timer) => window.clearTimeout(timer));
    diningTimers = [];
  }

  function updateDiningSteps(flow, activeIndex) {
    $$("p", flow).forEach((step, index) => {
      const distance = index - activeIndex;
      const age = activeIndex - index;
      const revealed = activeIndex >= 0 && index <= activeIndex;
      step.style.setProperty("--dining-step-y", `${distance * 58}px`);
      step.classList.toggle("is-revealed", revealed);
      step.classList.toggle("is-active", revealed && distance === 0);
      step.classList.toggle("is-complete", revealed && distance < 0);
      step.classList.toggle("is-age-2", revealed && age === 2);
      step.classList.toggle("is-age-3", revealed && age === 3);
      step.classList.toggle("is-age-4", revealed && age >= 4);
      step.setAttribute("aria-hidden", String(!revealed));
    });
  }

  function setDiningState(nextState) {
    diningState = nextState;
    diningScene.dataset.diningState = nextState;
    diningScene.classList.remove("is-completing");
    const queryProcessing = false;
    const resultsVisible = nextState === "results";
    const detailProcessing = nextState === "detail-processing";
    const detailVisible = nextState === "detail";
    diningQueryProcessing.setAttribute("aria-hidden", String(!queryProcessing));
    diningResults.setAttribute("aria-hidden", String(!resultsVisible));
    diningDetailProcessing.setAttribute("aria-hidden", String(!detailProcessing));
    diningDetail.setAttribute("aria-hidden", String(!detailVisible));
    syncDiningPresentation();
  }

  function runDiningSteps(flow, delays, duration, onComplete) {
    clearDiningTimers();
    const runToken = ++diningRunToken;
    updateDiningSteps(flow, -1);
    delays.forEach((delay, index) => {
      diningTimers.push(window.setTimeout(() => {
        if (runToken !== diningRunToken) return;
        updateDiningSteps(flow, index);
      }, delay));
    });
    diningTimers.push(
      window.setTimeout(() => {
        if (runToken !== diningRunToken) return;
        diningScene.classList.add("is-completing");
      }, Math.max(0, duration - 260)),
      window.setTimeout(() => {
        if (runToken !== diningRunToken) return;
        onComplete();
      }, duration)
    );
  }

  function startDiningQuery() {
    if (baseRoute !== "now" || currentNowScene !== "dining" || diningState !== "idle") return;
    diningResultsScroll.scrollTop = 0;
    diningDetailScroll.scrollTop = 0;
    setDiningState("query-processing");
    runVoiceTaskProcessor({
      kind: "dining",
      question: "这周边有什么好吃的",
      steps: ["识别附近餐饮需求", "确认当前位置", "比较步行范围内餐厅", "核对营业与人均信息", "整理推荐餐厅"],
      delays: [180, 760, 1320, 1960, 2580],
      duration: 3260,
      onComplete: () => revealSceneFromVoice(diningScene, () => {
        setDiningState("results");
        diningResultsScroll.scrollTop = 0;
      }, () => diningResultsScroll.focus({ preventScroll: true }))
    });
  }

  function startDiningDetail() {
    if (diningState !== "results") return;
    diningSavedResultsScroll = diningResultsScroll.scrollTop;
    setDiningState("detail-processing");
    runDiningSteps(diningDetailSteps, [70, 360, 920, 1540, 2010], 2500, () => {
      setDiningState("detail");
      diningDetailScroll.scrollTop = 0;
      window.setTimeout(() => $("h1", diningDetail).focus?.({ preventScroll: true }), 40);
    });
  }

  function returnToDiningResults() {
    clearDiningTimers();
    diningRunToken += 1;
    setDiningState("results");
    updateDiningSteps(diningDetailSteps, -1);
    diningResultsScroll.scrollTop = diningSavedResultsScroll;
    diningFeaturedRestaurant.focus({ preventScroll: true });
  }

  function resetDiningExperience() {
    if (activeVoiceTask === "dining") closeVoiceTaskProcessor({ immediate: true });
    closeDiningFollowup({ immediate: true, restoreFocus: false });
    closeDiningTasteFollowup({ immediate: true, restoreFocus: false });
    clearDiningTimers();
    diningRunToken += 1;
    diningSavedResultsScroll = 0;
    updateDiningSteps(diningQuerySteps, -1);
    updateDiningSteps(diningDetailSteps, -1);
    setDiningState("idle");
    diningResultsScroll.scrollTop = 0;
    diningDetailScroll.scrollTop = 0;
  }

  function clearTravelTimers() {
    travelTimers.forEach((timer) => window.clearTimeout(timer));
    travelTimers = [];
  }

  function setTravelState(nextState) {
    travelState = nextState;
    travelScene.dataset.travelState = nextState;
    travelScene.classList.remove("is-completing");
    const processingVisible = false;
    const resultsVisible = nextState === "results";
    travelQueryProcessing.setAttribute("aria-hidden", String(!processingVisible));
    travelResults.setAttribute("aria-hidden", String(!resultsVisible));
    syncTravelPresentation();
  }

  function travelAirportFor(city) {
    return {
      上海: "上海虹桥",
      深圳: "深圳宝安",
      北京: "北京首都",
      杭州: "杭州萧山",
      广州: "广州白云",
      成都: "成都天府"
    }[city] || city;
  }

  function updateTravelRoute() {
    const origin = travelOriginSelect.value;
    const destination = travelDestinationSelect.value;
    travelOriginDisplay.textContent = origin;
    travelDestinationDisplay.textContent = destination;
    travelRoute.setAttribute("aria-label", `${origin}到${destination}`);
    travelResults.setAttribute("aria-label", `${origin}至${destination}可选航班`);
    travelFlightRouteCopies.forEach((copy) => {
      copy.textContent = `${travelAirportFor(origin)} → ${travelAirportFor(destination)}`;
    });
  }

  function startTravelQuery() {
    if (baseRoute !== "now" || currentNowScene !== "travel" || travelState !== "idle") return;
    clearTravelTimers();
    travelRunToken += 1;
    travelResultsScroll.scrollTop = 0;
    travelFlightOptions.forEach((option) => {
      option.classList.remove("is-selected");
      option.setAttribute("aria-pressed", "false");
    });
    setTravelState("query-processing");
    runVoiceTaskProcessor({
      kind: "travel",
      question: "我最近要去深圳出差，帮我看下机票",
      steps: ["识别出差目的地", "确认当前出发地", "查询可选航班", "比较时间与价格", "整理购票信息"],
      delays: [180, 760, 1320, 1960, 2580],
      duration: 3260,
      onComplete: () => revealSceneFromVoice(travelScene, () => {
        setTravelState("results");
        travelResultsScroll.scrollTop = 0;
      }, () => travelResultsScroll.focus({ preventScroll: true }))
    });
  }

  function resetTravelExperience() {
    if (activeVoiceTask === "travel") closeVoiceTaskProcessor({ immediate: true });
    clearTravelTimers();
    travelRunToken += 1;
    updateDiningSteps(travelQuerySteps, -1);
    travelFlightOptions.forEach((option) => {
      option.classList.remove("is-selected");
      option.setAttribute("aria-pressed", "false");
    });
    travelFlightFilters.forEach((filter) => {
      const isAll = filter.dataset.travelFilter === "all";
      filter.classList.toggle("is-active", isAll);
      filter.classList.remove("is-open");
      if (isAll) filter.setAttribute("aria-pressed", "true");
      else filter.setAttribute("aria-expanded", "false");
    });
    travelOriginSelect.value = "上海";
    travelDestinationSelect.value = "深圳";
    updateTravelRoute();
    setTravelState("idle");
    travelResultsScroll.scrollTop = 0;
  }

  travelOriginSelect.addEventListener("change", () => {
    updateTravelRoute();
    showToast(`出发地已改为${travelOriginSelect.value}`);
  });

  travelDestinationSelect.addEventListener("change", () => {
    updateTravelRoute();
    showToast(`目的地已改为${travelDestinationSelect.value}`);
  });

  travelFlightFilters.forEach((filter) => {
    filter.addEventListener("click", () => {
      const isAll = filter.dataset.travelFilter === "all";
      if (isAll) {
        travelFlightFilters.forEach((item) => {
          const itemIsAll = item.dataset.travelFilter === "all";
          item.classList.toggle("is-active", itemIsAll);
          item.classList.remove("is-open");
          if (itemIsAll) item.setAttribute("aria-pressed", "true");
          else item.setAttribute("aria-expanded", "false");
        });
        return;
      }
      const willOpen = !filter.classList.contains("is-open");
      travelFlightFilters.forEach((item) => {
        if (item.dataset.travelFilter === "all") return;
        const open = item === filter && willOpen;
        item.classList.toggle("is-open", open);
        item.setAttribute("aria-expanded", String(open));
      });
    });
  });

  travelFlightOptions.forEach((option) => {
    option.addEventListener("click", () => {
      travelFlightOptions.forEach((item) => {
        const selected = item === option;
        item.classList.toggle("is-selected", selected);
        item.setAttribute("aria-pressed", String(selected));
      });
      showToast(`已选择 ${option.dataset.flight} 航班`);
    });
  });

  diningFeaturedRestaurant.addEventListener("click", startDiningDetail);
  diningDetailBack.addEventListener("click", returnToDiningResults);

  diningCategoryFilters.forEach((filter) => {
    filter.addEventListener("click", () => {
      diningCategoryFilters.forEach((item) => {
        const active = item === filter;
        item.classList.toggle("is-active", active);
        item.setAttribute("aria-pressed", String(active));
      });
    });
  });

  diningOptionFilters.forEach((filter) => {
    filter.addEventListener("click", () => {
      const willOpen = !filter.classList.contains("is-open");
      diningOptionFilters.forEach((item) => {
        const open = item === filter && willOpen;
        item.classList.toggle("is-open", open);
        item.setAttribute("aria-expanded", String(open));
      });
    });
  });

  const homeContextSteps = [
    "读取当前首页上下文",
    "核对需要处理的事项",
    "整理简短回答"
  ];

  function clearHomeContextTimers() {
    homeContextTimers.forEach((timer) => window.clearTimeout(timer));
    homeContextTimers = [];
  }

  function showHomeContextStatus(text, { initial = false } = {}) {
    if (initial) {
      homeContextStatus.textContent = text;
      homeContextStatus.classList.remove("is-changing");
      requestAnimationFrame(() => homeContextStatus.classList.add("is-visible"));
      return;
    }
    homeContextStatus.classList.add("is-changing");
    homeContextTimers.push(window.setTimeout(() => {
      homeContextStatus.textContent = text;
      homeContextStatus.classList.remove("is-changing");
      homeContextStatus.classList.add("is-visible");
    }, 180));
  }

  function openHomeContextAnswer() {
    clearHomeContextTimers();
    resetVoiceHold();
    homeContextPanel.classList.remove("is-answer-ready");
    homeContextAnswer.setAttribute("aria-hidden", "true");
    homeContextStatus.classList.remove("is-visible", "is-changing");
    homeContextStatus.textContent = "";
    homeContextPanel.setAttribute("aria-hidden", "false");
    bottomSystem.classList.add("home-context-active");
    homeVoice.classList.add("is-home-context");

    homeContextSteps.forEach((step, index) => {
      homeContextTimers.push(window.setTimeout(() => {
        showHomeContextStatus(step, { initial: index === 0 });
      }, 240 + index * 680));
    });

    homeContextTimers.push(window.setTimeout(() => {
      homeContextStatus.classList.add("is-changing");
      homeContextPanel.classList.add("is-answer-ready");
      homeContextAnswer.setAttribute("aria-hidden", "false");
      window.setTimeout(() => homeContextClose.focus({ preventScroll: true }), 320);
    }, 2440));
  }

  function closeHomeContextAnswer({ immediate = false, restoreFocus = true } = {}) {
    clearHomeContextTimers();
    if (immediate) homeVoice.style.transition = "none";
    homeVoice.classList.remove("is-home-context");
    bottomSystem.classList.remove("home-context-active");
    homeContextPanel.classList.remove("is-answer-ready");
    homeContextPanel.setAttribute("aria-hidden", "true");
    homeContextAnswer.setAttribute("aria-hidden", "true");
    homeContextStatus.classList.remove("is-visible", "is-changing");
    homeContextStatus.textContent = "";
    if (immediate) requestAnimationFrame(() => homeVoice.style.removeProperty("transition"));
    if (restoreFocus && currentNowScene === "home" && baseRoute === "now") {
      window.setTimeout(() => commandTrigger.focus({ preventScroll: true }), immediate ? 0 : 320);
    }
  }

  const diningFollowupSteps = [
    "识别当前列表中的第一家餐厅",
    "检索门店高频招牌菜",
    "核对菜品名称与推荐顺序",
    "整理招牌菜回答"
  ];

  function clearDiningFollowupTimers() {
    diningFollowupTimers.forEach((timer) => window.clearTimeout(timer));
    diningFollowupTimers = [];
  }

  function showDiningFollowupStatus(text, { initial = false } = {}) {
    if (initial) {
      diningFollowupStatus.textContent = text;
      diningFollowupStatus.classList.remove("is-changing");
      requestAnimationFrame(() => diningFollowupStatus.classList.add("is-visible"));
      return;
    }
    diningFollowupStatus.classList.add("is-changing");
    diningFollowupTimers.push(window.setTimeout(() => {
      diningFollowupStatus.textContent = text;
      diningFollowupStatus.classList.remove("is-changing");
      diningFollowupStatus.classList.add("is-visible");
    }, 180));
  }

  function resetDiningEntityActions() {
    selectedDiningDish = "";
    diningDishEntities.forEach((entity) => {
      entity.classList.remove("is-selected");
      entity.setAttribute("aria-pressed", "false");
    });
    diningEntityActions.classList.remove("is-visible");
    diningEntityActions.setAttribute("aria-hidden", "true");
    diningFavoriteAction.setAttribute("aria-pressed", "false");
    diningCartAction.setAttribute("aria-pressed", "false");
  }

  function setDiningFollowupResume(kind = "") {
    window.clearTimeout(diningResumeCompactTimer);
    diningResumeCompactTimer = 0;
    resumableDiningAnswer = kind;
    const active = Boolean(kind);
    const isTasteAnswer = kind === "taste";
    homeVoice.classList.toggle("has-resumable-answer", active);
    homeVoice.classList.remove("is-resume-compact");
    homeVoiceResumeLabel.hidden = !active;
    homeVoiceResumeLabel.textContent = isTasteAnswer ? "雨润田这家店…" : "第一家店有哪些…";
    commandTrigger.setAttribute(
      "aria-label",
      active
        ? `重新展开：${isTasteAnswer ? "雨润田这家店口味辣吗？" : "第一家店有哪些招牌菜"}`
        : "按住说话"
    );

    if (active) {
      diningResumeCompactTimer = window.setTimeout(() => {
        const panelIsClosed = !homeVoice.classList.contains("is-dining-followup")
          && !homeVoice.classList.contains("is-dining-taste");
        if (homeVoice.classList.contains("has-resumable-answer") && panelIsClosed) {
          homeVoice.classList.add("is-resume-compact");
        }
      }, 5000);
    }
  }

  function openDiningFollowup() {
    clearDiningFollowupTimers();
    resetVoiceHold();
    resetDiningEntityActions();
    setDiningFollowupResume("");
    diningFollowupPanel.classList.remove("is-answer-ready");
    diningFollowupAnswer.setAttribute("aria-hidden", "true");
    diningFollowupStatus.classList.remove("is-visible", "is-changing");
    diningFollowupStatus.textContent = "";
    diningFollowupPanel.setAttribute("aria-hidden", "false");
    bottomSystem.classList.add("dining-followup-active");
    homeVoice.classList.add("is-dining-followup");

    diningFollowupSteps.forEach((step, index) => {
      diningFollowupTimers.push(window.setTimeout(() => {
        showDiningFollowupStatus(step, { initial: index === 0 });
      }, 260 + index * 720));
    });

    diningFollowupTimers.push(window.setTimeout(() => {
      diningFollowupStatus.classList.add("is-changing");
      diningFollowupPanel.classList.add("is-answer-ready");
      diningFollowupAnswer.setAttribute("aria-hidden", "false");
      window.setTimeout(() => diningDishEntities[0]?.focus({ preventScroll: true }), 360);
    }, 3220));
  }

  function reopenDiningFollowup() {
    clearDiningFollowupTimers();
    resetVoiceHold();
    resetDiningEntityActions();
    setDiningFollowupResume("");
    diningFollowupStatus.classList.remove("is-visible", "is-changing");
    diningFollowupStatus.textContent = "";
    diningFollowupPanel.classList.add("is-answer-ready");
    diningFollowupPanel.setAttribute("aria-hidden", "false");
    diningFollowupAnswer.setAttribute("aria-hidden", "false");
    bottomSystem.classList.add("dining-followup-active");
    homeVoice.classList.add("is-dining-followup");
    window.setTimeout(() => diningFollowupClose.focus({ preventScroll: true }), 320);
  }

  function closeDiningFollowup({ immediate = false, restoreFocus = true } = {}) {
    clearDiningFollowupTimers();
    const shouldResume = !immediate && diningFollowupPanel.classList.contains("is-answer-ready");
    if (immediate) homeVoice.style.transition = "none";
    homeVoice.classList.remove("is-dining-followup");
    bottomSystem.classList.remove("dining-followup-active");
    diningFollowupPanel.classList.remove("is-answer-ready");
    diningFollowupPanel.setAttribute("aria-hidden", "true");
    diningFollowupAnswer.setAttribute("aria-hidden", "true");
    diningFollowupStatus.classList.remove("is-visible", "is-changing");
    resetDiningEntityActions();
    setDiningFollowupResume(shouldResume ? "dishes" : "");
    if (immediate) requestAnimationFrame(() => homeVoice.style.removeProperty("transition"));
    if (restoreFocus && diningState === "results") {
      window.setTimeout(() => commandTrigger.focus({ preventScroll: true }), immediate ? 0 : 320);
    }
  }

  const diningTasteSteps = [
    "理解关于雨润田口味的问题",
    "核对菜系与常见口味反馈",
    "整理辣度与点餐建议"
  ];

  function clearDiningTasteTimers() {
    diningTasteTimers.forEach((timer) => window.clearTimeout(timer));
    diningTasteTimers = [];
  }

  function showDiningTasteStatus(text, { initial = false } = {}) {
    if (initial) {
      diningTasteStatus.textContent = text;
      diningTasteStatus.classList.remove("is-changing");
      requestAnimationFrame(() => diningTasteStatus.classList.add("is-visible"));
      return;
    }
    diningTasteStatus.classList.add("is-changing");
    diningTasteTimers.push(window.setTimeout(() => {
      diningTasteStatus.textContent = text;
      diningTasteStatus.classList.remove("is-changing");
      diningTasteStatus.classList.add("is-visible");
    }, 180));
  }

  function resetDiningConversationHistory() {
    homeVoice.classList.remove("is-conversation-expanded");
    diningTastePanel.classList.remove("is-history-expanded");
    diningHistoryToggle.setAttribute("aria-expanded", "false");
    diningConversationHistory.setAttribute("aria-hidden", "true");
    diningConversationHistory.scrollTop = 0;
  }

  function openDiningTasteFollowup() {
    clearDiningTasteTimers();
    resetVoiceHold();
    setDiningFollowupResume("");
    resetDiningConversationHistory();
    diningTastePanel.classList.remove("is-answer-ready");
    diningTasteAnswer.setAttribute("aria-hidden", "true");
    diningHistoryToggle.disabled = true;
    diningTasteStatus.classList.remove("is-visible", "is-changing");
    diningTasteStatus.textContent = "";
    diningTastePanel.setAttribute("aria-hidden", "false");
    bottomSystem.classList.add("dining-taste-active");
    homeVoice.classList.add("is-dining-taste");

    diningTasteSteps.forEach((step, index) => {
      diningTasteTimers.push(window.setTimeout(() => {
        showDiningTasteStatus(step, { initial: index === 0 });
      }, 240 + index * 700));
    });

    diningTasteTimers.push(window.setTimeout(() => {
      diningTasteStatus.classList.add("is-changing");
      diningTastePanel.classList.add("is-answer-ready");
      diningTasteAnswer.setAttribute("aria-hidden", "false");
      diningHistoryToggle.disabled = false;
      window.setTimeout(() => diningTasteClose.focus({ preventScroll: true }), 340);
    }, 2520));
  }

  function reopenDiningTasteFollowup() {
    clearDiningTasteTimers();
    resetVoiceHold();
    setDiningFollowupResume("");
    resetDiningConversationHistory();
    diningTasteStatus.classList.remove("is-visible", "is-changing");
    diningTasteStatus.textContent = "";
    diningTastePanel.classList.add("is-answer-ready");
    diningTastePanel.setAttribute("aria-hidden", "false");
    diningTasteAnswer.setAttribute("aria-hidden", "false");
    diningHistoryToggle.disabled = false;
    bottomSystem.classList.add("dining-taste-active");
    homeVoice.classList.add("is-dining-taste");
    window.setTimeout(() => diningTasteClose.focus({ preventScroll: true }), 320);
  }

  function closeDiningTasteFollowup({ immediate = false, restoreFocus = true } = {}) {
    clearDiningTasteTimers();
    const shouldResume = !immediate && diningTastePanel.classList.contains("is-answer-ready");
    if (immediate) homeVoice.style.transition = "none";
    homeVoice.classList.remove("is-dining-taste", "is-conversation-expanded");
    bottomSystem.classList.remove("dining-taste-active");
    diningTastePanel.classList.remove("is-answer-ready", "is-history-expanded");
    diningTastePanel.setAttribute("aria-hidden", "true");
    diningTasteAnswer.setAttribute("aria-hidden", "true");
    diningConversationHistory.setAttribute("aria-hidden", "true");
    diningTasteStatus.classList.remove("is-visible", "is-changing");
    diningTasteStatus.textContent = "";
    diningHistoryToggle.setAttribute("aria-expanded", "false");
    diningHistoryToggle.disabled = true;
    setDiningFollowupResume(shouldResume ? "taste" : "");
    if (immediate) requestAnimationFrame(() => homeVoice.style.removeProperty("transition"));
    if (restoreFocus && diningState === "results") {
      window.setTimeout(() => commandTrigger.focus({ preventScroll: true }), immediate ? 0 : 320);
    }
  }

  function toggleDiningConversationHistory() {
    if (diningHistoryToggle.disabled) return;
    const expanded = diningHistoryToggle.getAttribute("aria-expanded") !== "true";
    homeVoice.classList.toggle("is-conversation-expanded", expanded);
    diningTastePanel.classList.toggle("is-history-expanded", expanded);
    diningHistoryToggle.setAttribute("aria-expanded", String(expanded));
    diningConversationHistory.setAttribute("aria-hidden", String(!expanded));
    if (expanded) diningConversationHistory.scrollTop = 0;
  }

  diningDishEntities.forEach((entity) => {
    entity.setAttribute("aria-pressed", "false");
    entity.addEventListener("click", () => {
      selectedDiningDish = entity.dataset.dish;
      diningDishEntities.forEach((item) => {
        const selected = item === entity;
        item.classList.toggle("is-selected", selected);
        item.setAttribute("aria-pressed", String(selected));
      });
      diningFavoriteAction.setAttribute("aria-pressed", "false");
      diningCartAction.setAttribute("aria-pressed", "false");
      diningEntityActions.classList.add("is-visible");
      diningEntityActions.setAttribute("aria-hidden", "false");
    });
  });

  diningFavoriteAction.addEventListener("click", () => {
    const nextPressed = diningFavoriteAction.getAttribute("aria-pressed") !== "true";
    diningFavoriteAction.setAttribute("aria-pressed", String(nextPressed));
    showToast(nextPressed ? `已收藏${selectedDiningDish}` : `已取消收藏${selectedDiningDish}`);
  });

  diningCartAction.addEventListener("click", () => {
    const nextPressed = diningCartAction.getAttribute("aria-pressed") !== "true";
    diningCartAction.setAttribute("aria-pressed", String(nextPressed));
    showToast(nextPressed ? `${selectedDiningDish}已加入购物车` : `${selectedDiningDish}已移出购物车`);
  });

  diningFollowupClose.addEventListener("click", () => closeDiningFollowup());
  diningTasteClose.addEventListener("click", () => closeDiningTasteFollowup());
  diningHistoryToggle.addEventListener("click", toggleDiningConversationHistory);
  homeContextClose.addEventListener("click", () => closeHomeContextAnswer());
  voiceTaskClose.addEventListener("click", () => cancelVoiceTaskProcessor());
  homeContextPanel.addEventListener("keydown", (event) => {
    if (event.key === "Escape") closeHomeContextAnswer();
  });
  diningFollowupPanel.addEventListener("keydown", (event) => {
    if (event.key === "Escape") closeDiningFollowup();
  });
  diningTastePanel.addEventListener("keydown", (event) => {
    if (event.key !== "Escape") return;
    if (diningTastePanel.classList.contains("is-history-expanded")) toggleDiningConversationHistory();
    else closeDiningTasteFollowup();
  });

  function setVoiceAxis(direction = "center", progress = 0) {
    const bounded = Math.max(0, Math.min(1, progress));
    const privateActive = direction === "private";
    const collabActive = direction === "collab";
    const edgeWidth = `${Math.round(20 + bounded * 80)}%`;
    const activeOpacity = String(0.52 + bounded * 0.48);

    homeVoice.style.setProperty("--voice-private-width", privateActive ? edgeWidth : "0%");
    homeVoice.style.setProperty("--voice-collab-width", collabActive ? edgeWidth : "0%");
    homeVoice.style.setProperty("--voice-private-opacity", privateActive ? activeOpacity : direction === "center" ? "0.34" : "0.08");
    homeVoice.style.setProperty("--voice-collab-opacity", collabActive ? activeOpacity : direction === "center" ? "0.34" : "0.08");
    homeVoice.classList.toggle("is-dragging-private", privateActive);
    homeVoice.classList.toggle("is-dragging-collab", collabActive);
    homeVoice.classList.toggle("is-committed", direction !== "center" && bounded >= 0.62);
  }

  function resetVoiceHold() {
    window.clearTimeout(voiceHoldTimer);
    voiceHoldTimer = 0;
    voiceHoldActive = false;
    voiceDragProgress = 0;
    voiceDragDirection = "center";
    homeVoice.classList.remove("is-holding", "is-dragging-private", "is-dragging-collab", "is-committed");
    homeVoice.style.setProperty("--voice-private-width", "0%");
    homeVoice.style.setProperty("--voice-collab-width", "0%");
    homeVoice.style.setProperty("--voice-private-opacity", "0");
    homeVoice.style.setProperty("--voice-collab-opacity", "0");
    commandTrigger.setAttribute("aria-pressed", "false");
  }

  function resetVoiceSpatialSpace({ immediate = false } = {}) {
    closePrivateLive({ restoreFocus: false, immediate, createNote: false });
    closePrivateNoteReader({ restoreFocus: false, immediate });
    hidePrivateNoteFlow({ resetSession: true });
    resetPrivateGreeting();
    resetVoiceHold();
    deviceScreen.classList.remove("voice-space-active", "voice-space-private", "voice-space-collab");
    homeVoice.classList.remove("is-space-private", "is-space-collab");
    [aiPrivateSurface, aiCollabSurface].forEach((surface) => {
      if (immediate) surface.style.transition = "none";
      surface.classList.remove("is-expanded", "is-visible");
      surface.setAttribute("aria-hidden", "true");
      if (immediate) requestAnimationFrame(() => surface.style.removeProperty("transition"));
    });
  }

  function expandVoiceSpace(direction) {
    const privateSpace = direction === "private";
    const surface = privateSpace ? aiPrivateSurface : aiCollabSurface;
    const otherSurface = privateSpace ? aiCollabSurface : aiPrivateSurface;

    voiceHoldActive = false;
    setDiningFollowupResume("");
    voiceDragProgress = 0;
    voiceDragDirection = "center";
    otherSurface.classList.remove("is-expanded", "is-visible");
    otherSurface.setAttribute("aria-hidden", "true");
    deviceScreen.classList.remove("voice-space-private", "voice-space-collab");
    deviceScreen.classList.add("voice-space-active", privateSpace ? "voice-space-private" : "voice-space-collab");
    homeVoice.classList.remove("is-holding", "is-dragging-private", "is-dragging-collab", "is-committed", "is-space-private", "is-space-collab");
    homeVoice.classList.add(privateSpace ? "is-space-private" : "is-space-collab");
    homeVoice.style.setProperty("--voice-private-width", "0%");
    homeVoice.style.setProperty("--voice-collab-width", "0%");
    homeVoice.style.setProperty("--voice-private-opacity", "0");
    homeVoice.style.setProperty("--voice-collab-opacity", "0");
    commandTrigger.setAttribute("aria-pressed", "false");
    resetPrivateGreeting();
    surface.setAttribute("aria-hidden", "false");
    surface.classList.add("is-visible");
    requestAnimationFrame(() => requestAnimationFrame(() => surface.classList.add("is-expanded")));
  }

  function beginVoiceHold(event) {
    if (voicePointerId !== null || (event.pointerType === "mouse" && event.button !== 0)) return;
    voicePointerId = event.pointerId;
    voiceDragStartX = event.clientX;
    voiceDragProgress = 0;
    voiceDragDirection = "center";
    voiceHoldActive = false;
    commandTrigger.setPointerCapture(event.pointerId);
    voiceHoldTimer = window.setTimeout(() => {
      voiceHoldActive = true;
      homeVoice.classList.add("is-holding");
      commandTrigger.setAttribute("aria-pressed", "true");
      setVoiceAxis("center", 0);
    }, voiceHoldDelay);
  }

  function moveVoiceHold(event) {
    if (event.pointerId !== voicePointerId) return;
    const deltaX = event.clientX - voiceDragStartX;
    if (!voiceHoldActive) {
      if (event.pointerType === "mouse" && Math.abs(deltaX) > 8) {
        window.clearTimeout(voiceHoldTimer);
        voiceHoldTimer = 0;
        voiceHoldActive = true;
        homeVoice.classList.add("is-holding");
        commandTrigger.setAttribute("aria-pressed", "true");
        setVoiceAxis("center", 0);
      } else if (Math.abs(deltaX) > 12) {
        window.clearTimeout(voiceHoldTimer);
        voiceHoldTimer = 0;
        return;
      }
    }

    event.preventDefault();
    const distance = Math.abs(deltaX);
    voiceDragDirection = deltaX < -8 ? "private" : deltaX > 8 ? "collab" : "center";
    voiceDragProgress = voiceDragDirection === "center" ? 0 : Math.max(0, Math.min(1, (distance - 8) / 128));
    setVoiceAxis(voiceDragDirection, voiceDragProgress);
  }

  function finishVoiceHold(event, { cancelled = false } = {}) {
    if (event.pointerId !== voicePointerId) return;
    window.clearTimeout(voiceHoldTimer);
    voiceHoldTimer = 0;
    if (commandTrigger.hasPointerCapture(event.pointerId)) commandTrigger.releasePointerCapture(event.pointerId);
    voicePointerId = null;

    if (!voiceHoldActive) return;
    suppressCommandClickTemporarily();
    const completesSpace = !cancelled && voiceDragDirection !== "center" && voiceDragProgress >= 0.62;
    const startsDiningQuery = !cancelled && voiceDragDirection === "center" && currentNowScene === "dining" && baseRoute === "now" && diningState === "idle";
    const canStartDiningFollowup = !cancelled && voiceDragDirection === "center" && currentNowScene === "dining" && baseRoute === "now" && diningState === "results";
    const startsDiningTasteQuery = canStartDiningFollowup && (
      resumableDiningAnswer === "dishes" || homeVoice.classList.contains("is-dining-followup")
    );
    const startsDiningFollowup = canStartDiningFollowup
      && resumableDiningAnswer === ""
      && !homeVoice.classList.contains("is-dining-followup")
      && !homeVoice.classList.contains("is-dining-taste");
    const startsTravelQuery = !cancelled && voiceDragDirection === "center" && currentNowScene === "travel" && baseRoute === "now" && travelState === "idle";
    const startsPrivateGreeting = !cancelled && voiceDragDirection === "center" && deviceScreen.classList.contains("voice-space-private") && !privateGreetingComplete;
    const startsHomeContextAnswer = !cancelled && voiceDragDirection === "center" && currentNowScene === "home" && baseRoute === "now" && !deviceScreen.classList.contains("voice-space-active");
    if (completesSpace) expandVoiceSpace(voiceDragDirection);
    else {
      resetVoiceHold();
      if (startsPrivateGreeting) openPrivateGreeting();
      else if (startsDiningQuery) startDiningQuery();
      else if (startsDiningTasteQuery) {
        if (homeVoice.classList.contains("is-dining-followup")) {
          closeDiningFollowup({ immediate: true, restoreFocus: false });
        }
        openDiningTasteFollowup();
      }
      else if (startsDiningFollowup) openDiningFollowup();
      else if (startsTravelQuery) startTravelQuery();
      else if (startsHomeContextAnswer) openHomeContextAnswer();
    }
  }

  commandTrigger.addEventListener("pointerdown", beginVoiceHold);
  commandTrigger.addEventListener("pointermove", moveVoiceHold);
  commandTrigger.addEventListener("pointerup", (event) => finishVoiceHold(event));
  commandTrigger.addEventListener("pointercancel", (event) => finishVoiceHold(event, { cancelled: true }));
  commandTrigger.addEventListener("contextmenu", (event) => {
    if (voiceHoldActive) event.preventDefault();
  });
  prototypeNavigator.addEventListener("click", () => resetVoiceSpatialSpace({ immediate: true }), true);

  function openCommand() {
    closeProfile();
    commandLayer.classList.add("visible");
    commandLayer.setAttribute("aria-hidden", "false");
    layerScrim.classList.add("visible");
    setPrototypeActive("ai-command");
    window.setTimeout(() => commandInput.focus(), 300);
  }

  function closeCommand() {
    commandLayer.classList.remove("visible");
    commandLayer.setAttribute("aria-hidden", "true");
    layerScrim.classList.remove("visible");
    commandInput.value = "";
    commandResult.classList.remove("visible");
    commandResult.textContent = "";
    if (journalSearchLayer.classList.contains("visible")) setPrototypeActive("journal-search");
    else if (journalReaderView.classList.contains("visible")) setPrototypeActive("journal-open");
    else setPrototypeActive(baseRoute);
  }

  const proposalLayer = $("#proposalLayer");
  const closeProposalButton = $("#closeProposal");
  let liveMuted = true;
  let liveVideoOff = true;
  let privateLiveMuted = false;
  let privateLiveVideoOff = true;
  let privateNoteTimers = [];
  let privateNoteCreated = false;
  let privateGreetingTimer = 0;
  let privateGreetingStarted = false;
  let privateGreetingComplete = false;
  let memoryTimers = [];
  let memoryDismissTimer;
  let filingRunId = 0;
  let filingAnimations = [];
  let filingActive = false;
  let journalPrototypeState = "journal";
  const filingClasses = [
    "is-filing", "filing-focus", "filing-page-morph", "filing-book-open",
    "filing-page-insert", "filing-book-close", "filing-library-reveal", "filing-complete"
  ];
  const memoryCopy = [
    "整理刚才的对话",
    "提取经历中的关键片段",
    "整合已关联的多模态内容",
    "生成日记正文",
    "编排文字和视觉内容"
  ];

  function openProposal() {
    closeProfile();
    proposalLayer.classList.add("visible");
    proposalLayer.setAttribute("aria-hidden", "false");
    layerScrim.classList.add("visible");
    setPrototypeActive("library");
  }

  function closeProposal() {
    proposalLayer.classList.remove("visible");
    proposalLayer.setAttribute("aria-hidden", "true");
    if (!commandLayer.classList.contains("visible")) layerScrim.classList.remove("visible");
    setPrototypeActive(baseRoute);
  }

  function updateAILiveControls() {
    aiLiveView.dataset.muted = String(liveMuted);
    aiLiveView.dataset.videoOff = String(liveVideoOff);
    liveMuteButton.setAttribute("aria-pressed", String(liveMuted));
    liveMuteButton.setAttribute("aria-label", liveMuted ? "取消麦克风静音" : "将麦克风静音");
    liveMuteSymbol.src = liveMuted ? "assets/icons/sf-symbols/mic.fill.png" : "assets/icons/sf-symbols/mic.slash.fill.png";
    liveVideoButton.setAttribute("aria-pressed", String(liveVideoOff));
    liveVideoButton.setAttribute("aria-label", liveVideoOff ? "开启视频" : "关闭视频");
    liveVideoSymbol.src = liveVideoOff ? "assets/icons/sf-symbols/video.slash.fill.png" : "assets/icons/sf-symbols/video.fill.png";
    aiLiveSelfView.setAttribute("aria-hidden", String(liveVideoOff));

  }

  const privateNoteSteps = [
    "整理刚才的通话",
    "提取情绪变化",
    "编排情绪笔记"
  ];

  function resetPrivateGreeting() {
    window.clearTimeout(privateGreetingTimer);
    privateGreetingTimer = 0;
    privateGreetingStarted = false;
    privateGreetingComplete = false;
    aiPrivateSurface.classList.remove("has-chat-thread");
    privateChatThread.classList.remove("is-visible", "has-assistant");
    privateChatThread.setAttribute("aria-hidden", "true");
    privateChatUser.classList.remove("is-visible");
    privateChatAssistant.classList.remove("is-visible");
  }

  function openPrivateGreeting() {
    if (privateGreetingStarted || !deviceScreen.classList.contains("voice-space-private")) return;
    privateGreetingStarted = true;
    aiPrivateSurface.classList.add("has-chat-thread");
    privateChatThread.classList.add("is-visible");
    privateChatThread.setAttribute("aria-hidden", "false");
    requestAnimationFrame(() => privateChatUser.classList.add("is-visible"));
    privateGreetingTimer = window.setTimeout(() => {
      privateChatThread.classList.add("has-assistant");
      privateChatAssistant.classList.add("is-visible");
      privateGreetingComplete = true;
    }, 680);
  }

  function clearPrivateNoteTimers() {
    privateNoteTimers.forEach((timer) => window.clearTimeout(timer));
    privateNoteTimers = [];
  }

  function showPrivateNoteStatus(text, { initial = false } = {}) {
    if (initial) {
      privateNoteStatus.textContent = text;
      privateNoteStatus.classList.remove("is-changing");
      requestAnimationFrame(() => privateNoteStatus.classList.add("is-visible"));
      return;
    }
    privateNoteStatus.classList.add("is-changing");
    privateNoteTimers.push(window.setTimeout(() => {
      privateNoteStatus.textContent = text;
      privateNoteStatus.classList.remove("is-changing");
      privateNoteStatus.classList.add("is-visible");
    }, 180));
  }

  function startPrivateNoteGeneration() {
    if (privateNoteCreated) return;
    privateNoteCreated = true;
    clearPrivateNoteTimers();
    closePrivateNoteReader({ restoreFocus: false, immediate: true });
    aiPrivateSurface.classList.add("has-note-flow");
    privateNoteFlow.classList.add("is-visible");
    privateNoteFlow.setAttribute("aria-hidden", "false");
    privateNoteCard.dataset.state = "generating";
    privateNoteCard.removeAttribute("role");
    privateNoteCard.removeAttribute("aria-expanded");
    privateNoteCard.tabIndex = -1;
    privateNoteCard.setAttribute("aria-label", "情绪笔记生成中");
    privateNoteActions.setAttribute("aria-hidden", "true");
    privateNoteTransfer.setAttribute("aria-pressed", "false");
    privateNoteStatus.textContent = "";
    privateNoteStatus.classList.remove("is-visible", "is-changing");

    privateNoteSteps.forEach((step, index) => {
      privateNoteTimers.push(window.setTimeout(() => {
        showPrivateNoteStatus(step, { initial: index === 0 });
      }, 180 + index * 1120));
    });

    privateNoteTimers.push(window.setTimeout(() => {
      privateNoteStatus.classList.add("is-changing");
      privateNoteCard.dataset.state = "ready";
      privateNoteCard.setAttribute("role", "button");
      privateNoteCard.setAttribute("aria-expanded", "false");
      privateNoteCard.setAttribute("aria-label", "打开情绪笔记《迪士尼一日游》");
      privateNoteCard.tabIndex = 0;
      privateNoteActions.setAttribute("aria-hidden", "false");
      privateNoteTimers.push(window.setTimeout(() => {
        privateNoteStatus.textContent = "";
        privateNoteStatus.classList.remove("is-visible", "is-changing");
      }, 240));
      window.setTimeout(() => privateNoteDestroy.focus({ preventScroll: true }), 320);
    }, 4000));
  }

  function hidePrivateNoteFlow({ resetSession = false } = {}) {
    clearPrivateNoteTimers();
    closePrivateNoteReader({ restoreFocus: false, immediate: true });
    privateNoteFlow.classList.remove("is-visible");
    privateNoteFlow.setAttribute("aria-hidden", "true");
    privateNoteActions.setAttribute("aria-hidden", "true");
    privateNoteTransfer.setAttribute("aria-pressed", "false");
    privateNoteCard.dataset.state = "idle";
    privateNoteCard.removeAttribute("role");
    privateNoteCard.removeAttribute("aria-expanded");
    privateNoteCard.tabIndex = -1;
    privateNoteCard.setAttribute("aria-label", "情绪笔记生成中");
    privateNoteStatus.textContent = "";
    privateNoteStatus.classList.remove("is-visible", "is-changing");
    aiPrivateSurface.classList.remove("has-note-flow");
    if (resetSession) privateNoteCreated = false;
  }

  let privateNoteCarouselFrame = 0;

  function updatePrivateNoteActiveCard({ resetCopy = false } = {}) {
    window.cancelAnimationFrame(privateNoteCarouselFrame);
    privateNoteCarouselFrame = window.requestAnimationFrame(() => {
      const viewportCenter = privateNoteCardCarousel.scrollLeft + privateNoteCardCarousel.clientWidth / 2;
      let activeCard = privateNoteImageCards[0];
      let nearestDistance = Number.POSITIVE_INFINITY;

      privateNoteImageCards.forEach((card) => {
        const cardCenter = card.offsetLeft + card.offsetWidth / 2;
        const distance = Math.abs(cardCenter - viewportCenter);
        if (distance < nearestDistance) {
          nearestDistance = distance;
          activeCard = card;
        }
      });

      const activeIndex = privateNoteImageCards.indexOf(activeCard);
      privateNoteImageCards.forEach((card, index) => {
        card.classList.toggle("is-active", index === activeIndex);
        card.classList.toggle("is-before", index < activeIndex);
        card.classList.toggle("is-after", index > activeIndex);
      });
      const caption = activeCard?.dataset.caption || "";
      if (privateNoteCardCopyText.textContent !== caption) {
        privateNoteCardCopyText.textContent = caption;
        resetCopy = true;
      }
      if (resetCopy) privateNoteCardCopyScroll.scrollTop = 0;
    });
  }

  function snapPrivateNoteCarousel(targetIndex = null) {
    const viewportCenter = privateNoteCardCarousel.scrollLeft + privateNoteCardCarousel.clientWidth / 2;
    let activeCard = privateNoteImageCards[0];
    let nearestDistance = Number.POSITIVE_INFINITY;
    if (Number.isInteger(targetIndex)) {
      activeCard = privateNoteImageCards[Math.max(0, Math.min(privateNoteImageCards.length - 1, targetIndex))];
    } else {
      privateNoteImageCards.forEach((card) => {
        const distance = Math.abs(card.offsetLeft + card.offsetWidth / 2 - viewportCenter);
        if (distance < nearestDistance) {
          nearestDistance = distance;
          activeCard = card;
        }
      });
    }
    const targetLeft = activeCard.offsetLeft - (privateNoteCardCarousel.clientWidth - activeCard.offsetWidth) / 2;
    privateNoteCardCarousel.scrollTo({ left: targetLeft, behavior: "smooth" });
    updatePrivateNoteActiveCard({ resetCopy: true });
  }

  function enablePrivateNotePointerScroll(element, axis) {
    let pointerId = null;
    let startPoint = 0;
    let startScroll = 0;
    let dragDistance = 0;
    let startCardIndex = 0;

    element.addEventListener("pointerdown", (event) => {
      if (event.pointerType !== "mouse" || event.button !== 0) return;
      pointerId = event.pointerId;
      startPoint = axis === "x" ? event.clientX : event.clientY;
      startScroll = axis === "x" ? element.scrollLeft : element.scrollTop;
      dragDistance = 0;
      if (axis === "x") {
        startCardIndex = Math.max(0, privateNoteImageCards.findIndex((card) => card.classList.contains("is-active")));
      }
      element.setPointerCapture(pointerId);
      element.classList.add("is-dragging");
    });

    element.addEventListener("pointermove", (event) => {
      if (event.pointerId !== pointerId) return;
      const currentPoint = axis === "x" ? event.clientX : event.clientY;
      dragDistance = currentPoint - startPoint;
      const nextScroll = startScroll - (currentPoint - startPoint);
      if (axis === "x") element.scrollLeft = nextScroll;
      else element.scrollTop = nextScroll;
    });

    const finishPointerScroll = (event) => {
      if (event.pointerId !== pointerId) return;
      if (element.hasPointerCapture(pointerId)) element.releasePointerCapture(pointerId);
      pointerId = null;
      element.classList.remove("is-dragging");
      if (axis === "x") {
        const targetIndex = Math.abs(dragDistance) >= 38
          ? startCardIndex + (dragDistance < 0 ? 1 : -1)
          : null;
        snapPrivateNoteCarousel(targetIndex);
      }
    };

    element.addEventListener("pointerup", finishPointerScroll);
    element.addEventListener("pointercancel", finishPointerScroll);
  }

  function setPrivateNoteView(view = "document") {
    const stackViewActive = view === "stack";
    privateNoteReader.classList.toggle("is-stack-view", stackViewActive);
    privateNoteViewDocument.classList.toggle("is-active", !stackViewActive);
    privateNoteViewStack.classList.toggle("is-active", stackViewActive);
    privateNoteViewDocument.setAttribute("aria-selected", String(!stackViewActive));
    privateNoteViewStack.setAttribute("aria-selected", String(stackViewActive));
    privateNoteDocument.setAttribute("aria-hidden", String(stackViewActive));
    privateNoteStackView.setAttribute("aria-hidden", String(!stackViewActive));

    if (stackViewActive) {
      privateNoteCardCarousel.scrollLeft = 0;
      privateNoteCardCopyScroll.scrollTop = 0;
      updatePrivateNoteActiveCard({ resetCopy: true });
      window.setTimeout(() => privateNoteCardCarousel.focus({ preventScroll: true }), 180);
    } else {
      privateNoteDocument.scrollTop = 0;
    }
  }

  function openPrivateNoteShare() {
    if (!privateNoteReader.classList.contains("is-visible")) return;
    privateNoteShareLayer.classList.add("is-visible");
    privateNoteShareLayer.setAttribute("aria-hidden", "false");
    privateNoteShareButton.setAttribute("aria-expanded", "true");
    window.setTimeout(() => privateNoteSharePeople[0]?.focus({ preventScroll: true }), 260);
  }

  function closePrivateNoteShare({ restoreFocus = true } = {}) {
    privateNoteShareLayer.classList.remove("is-visible");
    privateNoteShareLayer.setAttribute("aria-hidden", "true");
    privateNoteShareButton.setAttribute("aria-expanded", "false");
    if (restoreFocus && privateNoteReader.classList.contains("is-visible")) {
      window.setTimeout(() => privateNoteShareButton.focus({ preventScroll: true }), 220);
    }
  }

  function openPrivateNoteReader() {
    if (privateNoteCard.dataset.state !== "ready") return;
    setPrivateNoteView("document");
    aiPrivateSurface.classList.add("note-reader-open");
    privateNoteReader.classList.add("is-visible");
    privateNoteReader.setAttribute("aria-hidden", "false");
    privateNoteCard.setAttribute("aria-expanded", "true");
    privateNoteDocument.scrollTop = 0;
    window.setTimeout(() => privateNoteBack.focus({ preventScroll: true }), 320);
  }

  function closePrivateNoteReader({ restoreFocus = true, immediate = false } = {}) {
    if (immediate) privateNoteReader.style.transition = "none";
    closePrivateNoteShare({ restoreFocus: false });
    setPrivateNoteView("document");
    privateNoteReader.classList.remove("is-visible");
    privateNoteReader.setAttribute("aria-hidden", "true");
    aiPrivateSurface.classList.remove("note-reader-open");
    privateNoteCard.setAttribute("aria-expanded", "false");
    if (immediate) requestAnimationFrame(() => privateNoteReader.style.removeProperty("transition"));
    if (restoreFocus && privateNoteCard.dataset.state === "ready") {
      window.setTimeout(() => privateNoteCard.focus({ preventScroll: true }), immediate ? 0 : 280);
    }
  }

  function updatePrivateLiveControls() {
    privateLiveMute.setAttribute("aria-pressed", String(privateLiveMuted));
    privateLiveMute.setAttribute("aria-label", privateLiveMuted ? "取消静音" : "静音");
    privateLiveMuteIcon.src = privateLiveMuted
      ? "assets/icons/sf-symbols/mic.slash.fill.png"
      : "assets/icons/sf-symbols/mic.fill.png";
    privateLiveVideo.setAttribute("aria-pressed", String(!privateLiveVideoOff));
    privateLiveVideo.setAttribute("aria-label", privateLiveVideoOff ? "打开摄像头" : "关闭摄像头");
    privateLiveVideoIcon.src = privateLiveVideoOff
      ? "assets/icons/sf-symbols/video.slash.fill.png"
      : "assets/icons/sf-symbols/video.fill.png";
  }

  function openPrivateLive() {
    if (!deviceScreen.classList.contains("voice-space-private") || !aiPrivateSurface.classList.contains("is-expanded")) return;
    privateLiveMuted = false;
    privateLiveVideoOff = true;
    updatePrivateLiveControls();
    privateLiveControls.setAttribute("aria-hidden", "false");
    deviceScreen.classList.add("private-live-active");
    window.setTimeout(() => privateLiveMute.focus({ preventScroll: true }), 320);
  }

  function closePrivateLive({ restoreFocus = true, immediate = false, createNote = true } = {}) {
    const wasActive = deviceScreen.classList.contains("private-live-active");
    if (immediate) privateLiveControls.style.transition = "none";
    deviceScreen.classList.remove("private-live-active");
    privateLiveControls.setAttribute("aria-hidden", "true");
    privateLiveMuted = false;
    privateLiveVideoOff = true;
    updatePrivateLiveControls();
    if (immediate) requestAnimationFrame(() => privateLiveControls.style.removeProperty("transition"));
    if (wasActive && createNote) startPrivateNoteGeneration();
    if (restoreFocus && homeVoice.classList.contains("is-space-private")) {
      window.setTimeout(() => aiLiveButton.focus({ preventScroll: true }), immediate ? 0 : 280);
    }
  }

  function clearMemoryTimers() {
    memoryTimers.forEach((timer) => window.clearTimeout(timer));
    memoryTimers = [];
    window.clearTimeout(memoryDismissTimer);
  }

  function cancelFilingAnimations() {
    filingRunId += 1;
    filingAnimations.forEach((animation) => animation.cancel());
    filingAnimations = [];
    filingActive = false;
    filingBookFlight.removeAttribute("style");
    filingBookStage.removeAttribute("style");
    filingLeftPage.removeAttribute("style");
    filingClosedAsset.removeAttribute("style");
    memoryCard.removeAttribute("style");
    journalDocument.removeAttribute("style");
    filingEntryAbstract.removeAttribute("style");
    journalActions.removeAttribute("style");
    secondaryView.classList.remove("filing-destination");
    myJournalGalleryCard.classList.remove("is-filing-target", "is-filing-settled");
  }

  function nextPaint() {
    return new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve)));
  }

  function filingAnimation(element, keyframes, duration, runId, easing = "cubic-bezier(0.2, 0.78, 0.2, 1)") {
    const reduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    const animation = element.animate(keyframes, {
      duration: reduced ? 1 : duration,
      easing,
      fill: "forwards"
    });
    filingAnimations.push(animation);
    return animation.finished.catch(() => undefined).then(() => {
      if (runId !== filingRunId) throw new Error("filing-cancelled");
    });
  }

  function filingPause(duration, runId) {
    return filingAnimation(memoryFlow, [{ opacity: 1 }, { opacity: 1 }], duration, runId, "linear");
  }

  function closeDeleteConfirmation() {
    journalDeleteConfirm.classList.remove("visible");
    journalDeleteConfirm.setAttribute("aria-hidden", "true");
  }

  function resetMemoryFlow() {
    clearMemoryTimers();
    cancelFilingAnimations();
    closeDeleteConfirmation();
    memoryFlow.classList.remove("visible", "formed", "from-live", "is-saved", "is-dismissing", ...filingClasses);
    memoryFlow.removeAttribute("data-filing-state");
    memoryFlow.dataset.state = "idle";
    memoryFlow.setAttribute("aria-hidden", "true");
    memoryGenerating.setAttribute("aria-hidden", "true");
    journalDocument.setAttribute("aria-hidden", "true");
    journalActions.setAttribute("aria-hidden", "true");
    memoryLines.replaceChildren();
    journalScroll.scrollTop = 0;
    journalSave.disabled = false;
    journalSave.setAttribute("aria-pressed", "false");
    filingBookFlight.setAttribute("aria-hidden", "true");
    deviceScreen.classList.remove("memory-flow-active");
  }

  function concealAILive() {
    aiLiveView.classList.remove("visible", "is-ending");
    aiLiveView.setAttribute("aria-hidden", "true");
    liveEndButton.disabled = false;
    deviceScreen.classList.remove("ai-live-active");
  }

  function appendMemoryLine(index) {
    $$(".memory-line", memoryLines).forEach((line) => {
      line.classList.remove("current");
      line.classList.add("past");
    });
    const line = document.createElement("p");
    line.className = "memory-line current";
    line.lang = "zh-CN";
    line.textContent = memoryCopy[index];
    memoryLines.append(line);
  }

  function showJournal() {
    clearMemoryTimers();
    memoryFlow.dataset.state = "journal";
    memoryGenerating.setAttribute("aria-hidden", "true");
    journalDocument.setAttribute("aria-hidden", "false");
    journalActions.setAttribute("aria-hidden", "false");
    journalScroll.scrollTop = 0;
    journalPrototypeState = "journal";
    setPrototypeActive("journal");
  }

  function startJournalGeneration({ fromLive = false } = {}) {
    clearMemoryTimers();
    if (!fromLive) {
      concealAILive();
      resetMemoryFlow();
      memoryFlow.classList.add("visible");
      requestAnimationFrame(() => memoryFlow.classList.add("formed"));
    }
    memoryFlow.classList.remove("from-live", "is-saved", "is-dismissing");
    memoryFlow.classList.add("visible", "formed");
    memoryFlow.dataset.state = "generating";
    memoryFlow.setAttribute("aria-hidden", "false");
    memoryGenerating.setAttribute("aria-hidden", "false");
    journalDocument.setAttribute("aria-hidden", "true");
    journalActions.setAttribute("aria-hidden", "true");
    memoryLines.replaceChildren();
    deviceScreen.classList.add("memory-flow-active");
    bottomSystem.classList.add("hidden-for-activity");
    setPrototypeActive("generating");
    appendMemoryLine(0);
    memoryTimers.push(window.setTimeout(() => appendMemoryLine(1), 1350));
    memoryTimers.push(window.setTimeout(() => appendMemoryLine(2), 2700));
    memoryTimers.push(window.setTimeout(() => appendMemoryLine(3), 4050));
    memoryTimers.push(window.setTimeout(() => appendMemoryLine(4), 5400));
    memoryTimers.push(window.setTimeout(showJournal, 7100));
  }

  function endLiveToJournal() {
    if (!aiLiveView.classList.contains("visible") || aiLiveView.classList.contains("is-ending")) return;
    clearMemoryTimers();
    liveEndButton.disabled = true;
    aiLiveView.classList.add("is-ending");
    memoryFlow.classList.remove("is-saved", "is-dismissing");
    memoryFlow.classList.add("visible", "from-live");
    memoryFlow.dataset.state = "contracting";
    memoryFlow.setAttribute("aria-hidden", "false");
    setPrototypeActive("generating");
    requestAnimationFrame(() => requestAnimationFrame(() => memoryFlow.classList.add("formed")));
    memoryTimers.push(window.setTimeout(() => {
      deviceScreen.classList.remove("ai-live-active");
      deviceScreen.classList.add("memory-flow-active");
    }, 250));
    memoryTimers.push(window.setTimeout(() => {
      concealAILive();
      startJournalGeneration({ fromLive: true });
    }, 660));
  }

  function dismissMemoryFlow() {
    if (!memoryFlow.classList.contains("visible")) return;
    clearMemoryTimers();
    cancelFilingAnimations();
    closeDeleteConfirmation();
    memoryFlow.classList.add("is-dismissing");
    memoryDismissTimer = window.setTimeout(() => {
      resetMemoryFlow();
      bottomSystem.classList.remove("hidden-for-activity");
      setPrototypeActive(baseRoute);
    }, 380);
  }

  function showJournalDirect(prototypeState = "journal") {
    concealAILive();
    resetMemoryFlow();
    memoryFlow.classList.add("visible", "formed");
    memoryFlow.dataset.state = "journal";
    memoryFlow.setAttribute("aria-hidden", "false");
    memoryGenerating.setAttribute("aria-hidden", "true");
    journalDocument.setAttribute("aria-hidden", "false");
    journalActions.setAttribute("aria-hidden", "false");
    deviceScreen.classList.add("memory-flow-active");
    bottomSystem.classList.add("hidden-for-activity");
    journalScroll.scrollTop = 0;
    journalPrototypeState = prototypeState;
    setPrototypeActive(prototypeState);
  }

  async function runJournalFiling() {
    if (filingActive || memoryFlow.dataset.state !== "journal") return;
    cancelFilingAnimations();
    const runId = filingRunId;
    filingActive = true;
    journalSave.disabled = true;
    journalSave.setAttribute("aria-pressed", "true");
    filingBookFlight.setAttribute("aria-hidden", "false");
    memoryFlow.classList.remove("is-saved", "is-dismissing");
    memoryFlow.classList.add("is-filing", "filing-focus");
    memoryFlow.dataset.filingState = "focus";

    try {
      await Promise.all([
        filingAnimation(journalActions, [
          { opacity: 1, transform: "translateY(0) scale(1)" },
          { opacity: 0, transform: "translateY(10px) scale(0.97)" }
        ], 190, runId),
        filingAnimation(memoryCard, [
          { transform: "translateY(0) scale(1)" },
          { transform: "translateY(-6px) scale(0.992)" }
        ], 190, runId)
      ]);

      memoryFlow.classList.add("filing-page-morph");
      memoryFlow.dataset.filingState = "page-morph";
      await Promise.all([
        filingAnimation(memoryCard, [
          {
            top: "70px",
            left: "20px",
            width: "390px",
            height: "720px",
            transform: "translateY(-6px) scale(0.992)",
            borderRadius: "38px",
            boxShadow: "0 26px 66px rgba(50, 65, 80, 0.18)"
          },
          {
            top: "263px",
            left: "216px",
            width: "152px",
            height: "220px",
            transform: "none",
            borderRadius: "12px 16px 16px 12px",
            boxShadow: "0 12px 25px rgba(53, 67, 80, 0.13)"
          }
        ], 440, runId),
        filingAnimation(journalDocument, [{ opacity: 1 }, { opacity: 0.08 }], 330, runId),
        filingAnimation(filingEntryAbstract, [{ opacity: 0 }, { opacity: 1 }], 330, runId)
      ]);

      memoryFlow.classList.add("filing-book-open");
      memoryFlow.dataset.filingState = "book-open";
      await filingAnimation(filingBookFlight, [
        { opacity: 0, transform: "translateY(14px) scale(0.96)" },
        { opacity: 1, transform: "translateY(0) scale(1)" }
      ], 330, runId);

      memoryFlow.classList.add("filing-page-insert");
      memoryFlow.dataset.filingState = "page-insert";
      await filingAnimation(memoryCard, [
        { top: "263px", left: "216px", width: "152px", height: "220px", opacity: 1 },
        { top: "268px", left: "220px", width: "144px", height: "208px", opacity: 1 }
      ], 390, runId);

      await filingPause(150, runId);

      memoryFlow.classList.add("filing-book-close");
      memoryFlow.dataset.filingState = "book-close";
      await Promise.all([
        filingAnimation(filingBookStage, [{ opacity: 1 }, { opacity: 0, offset: 0.86 }], 520, runId),
        filingAnimation(filingClosedAsset, [
          { transform: "rotateY(-176deg)", opacity: 0 },
          { transform: "rotateY(-34deg)", opacity: 1, offset: 0.76 },
          { transform: "rotateY(0deg)", opacity: 1 }
        ], 520, runId),
        filingAnimation(filingLeftPage, [{ opacity: 1 }, { opacity: 0, offset: 0.8 }], 520, runId),
        filingAnimation(memoryCard, [{ opacity: 1 }, { opacity: 0.68, offset: 0.62 }, { opacity: 0 }], 520, runId)
      ]);

      myJournalGalleryCard.classList.add("is-filing-target");
      closeJournalReader({ restoreNavigation: false });
      closeLibraryDetails({ restoreNavigation: false });
      secondaryView.classList.add("filing-destination");
      selectRoute("library");
      await nextPaint();
      if (runId !== filingRunId) throw new Error("filing-cancelled");

      memoryFlow.classList.add("filing-library-reveal");
      memoryFlow.dataset.filingState = "library-transition";
      const screenRect = deviceScreen.getBoundingClientRect();
      const wrapperRect = filingBookFlight.getBoundingClientRect();
      const targetRect = myJournalGalleryObject.getBoundingClientRect();
      const canvasScale = screenRect.width / 430;
      const targetScale = targetRect.width / wrapperRect.width;
      const flightX = (targetRect.left - wrapperRect.left) / canvasScale;
      const flightY = (targetRect.top - wrapperRect.top) / canvasScale;
      const flightTransform = `translate3d(${flightX}px, ${flightY}px, 0) scale(${targetScale})`;

      await Promise.all([
        filingAnimation($(".memory-flow-wash", memoryFlow), [{ opacity: 1 }, { opacity: 0 }], 620, runId),
        filingAnimation(filingBookFlight, [
          { transform: "translate3d(0, 0, 0) scale(1)" },
          { transform: flightTransform }
        ], 680, runId)
      ]);

      memoryFlow.dataset.filingState = "library";
      memoryFlow.classList.add("filing-complete");
      myJournalGalleryCard.classList.remove("is-filing-target");
      myJournalGalleryCard.classList.add("is-filing-settled");
      memoryFlow.classList.remove("visible", "formed");
      memoryFlow.setAttribute("aria-hidden", "true");
      deviceScreen.classList.remove("memory-flow-active");
      bottomSystem.classList.remove("hidden-for-activity");
      setPrototypeActive("library");
      secondaryView.classList.remove("filing-destination");
      filingAnimations.forEach((animation) => animation.cancel());
      filingAnimations = [];
      filingActive = false;
      await nextPaint();
      memoryFlow.classList.remove("is-filing", "filing-focus", "filing-page-morph", "filing-book-open", "filing-page-insert", "filing-book-close", "filing-library-reveal", "filing-complete");
      memoryFlow.dataset.state = "idle";
      memoryFlow.removeAttribute("data-filing-state");
      filingBookFlight.setAttribute("aria-hidden", "true");
      journalSave.disabled = false;
      journalSave.setAttribute("aria-pressed", "false");
    } catch (error) {
      if (error.message !== "filing-cancelled") throw error;
    } finally {
      if (runId === filingRunId) filingActive = false;
    }
  }

  function openAILive() {
    resetMemoryFlow();
    closeJournalReader({ restoreNavigation: false });
    closeSearch();
    closeProfile();
    if (commandLayer.classList.contains("visible")) closeCommand();
    if (proposalLayer.classList.contains("visible")) closeProposal();
    liveMuted = true;
    liveVideoOff = true;
    updateAILiveControls();
    aiLiveView.classList.add("visible");
    aiLiveView.classList.remove("is-ending");
    aiLiveView.setAttribute("aria-hidden", "false");
    deviceScreen.classList.add("ai-live-active");
    bottomSystem.classList.add("hidden-for-activity");
    setPrototypeActive("live");
    window.setTimeout(() => liveMuteButton.focus({ preventScroll: true }), 320);
  }

  function closeAILive({ restoreFocus = true } = {}) {
    concealAILive();
    bottomSystem.classList.remove("hidden-for-activity");
    setPrototypeActive(baseRoute);
    if (restoreFocus) window.setTimeout(() => aiLiveButton.focus({ preventScroll: true }), 330);
  }

  function runCommand(text) {
    const normalized = text.toLowerCase();
    let result = "已在当前活动情境中准备好这项操作，首页内容未移动。";
    if (normalized.includes("summarize") || normalized.includes("总结")) result = "进展已总结：首页层级已确定，连续性转场仍待处理。";
    if (normalized.includes("related") || normalized.includes("相关")) result = "已在 AIOS 和工作空间中找到 6 个相关对象，可加入当前活动。";
    if (normalized.includes("presentation") || normalized.includes("演示")) result = "已根据当前工作集准备演示文稿大纲，创建前可先查看。";
    if (["迪士尼", "disney", "8月17", "8 月 17", "城堡", "冰饮", "烟花"].some((keyword) => normalized.includes(keyword))) {
      result = "已找到 8 月 17 日《去迪士尼玩了一整天》，包含白天城堡照片、冰饮对象和夜晚烟花照片。";
    }
    commandResult.textContent = result;
    commandResult.classList.add("visible");
  }

  commandTrigger.addEventListener("click", (event) => {
    if (suppressNextCommandClick) {
      event.preventDefault();
      window.clearTimeout(suppressCommandClickTimer);
      suppressNextCommandClick = false;
      return;
    }
    event.preventDefault();
    if (homeVoice.classList.contains("has-resumable-answer") && currentNowScene === "dining" && baseRoute === "now") {
      if (resumableDiningAnswer === "taste") reopenDiningTasteFollowup();
      else reopenDiningFollowup();
    }
  });
  aiLiveButton.addEventListener("click", () => {
    if (homeVoice.classList.contains("is-space-private") && deviceScreen.classList.contains("voice-space-private")) {
      openPrivateLive();
      return;
    }
    openAILive();
  });
  privateLiveMute.addEventListener("click", () => {
    privateLiveMuted = !privateLiveMuted;
    updatePrivateLiveControls();
  });
  privateLiveVideo.addEventListener("click", () => {
    privateLiveVideoOff = !privateLiveVideoOff;
    updatePrivateLiveControls();
  });
  privateLiveEnd.addEventListener("click", () => closePrivateLive());
  privateSpaceBack.addEventListener("click", () => resetVoiceSpatialSpace());
  privateNoteCard.addEventListener("click", openPrivateNoteReader);
  privateNoteBack.addEventListener("click", () => closePrivateNoteReader());
  privateNoteViewDocument.addEventListener("click", () => setPrivateNoteView("document"));
  privateNoteViewStack.addEventListener("click", () => setPrivateNoteView("stack"));
  privateNoteShareButton.addEventListener("click", () => {
    if (privateNoteShareLayer.classList.contains("is-visible")) closePrivateNoteShare();
    else openPrivateNoteShare();
  });
  privateNoteShareBackdrop.addEventListener("click", () => closePrivateNoteShare());
  privateNoteSharePeople.forEach((button) => {
    button.addEventListener("click", () => {
      button.classList.toggle("is-selected");
      showToast(button.classList.contains("is-selected") ? "已选择分享对象" : "已取消选择");
    });
  });
  privateNoteShareCollections.forEach((button) => {
    button.addEventListener("click", () => {
      const selected = button.getAttribute("aria-pressed") !== "true";
      button.setAttribute("aria-pressed", String(selected));
      showToast(selected ? `已加入${button.dataset.privateShareCollection}` : `已从${button.dataset.privateShareCollection}移除`);
    });
  });
  privateNoteCardCarousel.addEventListener("scroll", () => updatePrivateNoteActiveCard(), { passive: true });
  privateNoteCardCarousel.addEventListener("keydown", (event) => {
    if (event.key !== "ArrowLeft" && event.key !== "ArrowRight") return;
    event.preventDefault();
    const activeIndex = Math.max(0, privateNoteImageCards.findIndex((card) => card.classList.contains("is-active")));
    const nextIndex = Math.max(0, Math.min(privateNoteImageCards.length - 1, activeIndex + (event.key === "ArrowRight" ? 1 : -1)));
    const nextCard = privateNoteImageCards[nextIndex];
    privateNoteCardCarousel.scrollTo({
      left: nextCard.offsetLeft - (privateNoteCardCarousel.clientWidth - nextCard.offsetWidth) / 2,
      behavior: "smooth"
    });
  });
  enablePrivateNotePointerScroll(privateNoteCardCarousel, "x");
  enablePrivateNotePointerScroll(privateNoteCardCopyScroll, "y");
  privateNoteCard.addEventListener("keydown", (event) => {
    if (event.key !== "Enter" && event.key !== " ") return;
    event.preventDefault();
    openPrivateNoteReader();
  });
  privateNoteDestroy.addEventListener("click", () => {
    hidePrivateNoteFlow();
    window.setTimeout(() => commandTrigger.focus({ preventScroll: true }), 260);
  });
  privateNoteTransfer.addEventListener("click", () => {
    privateNoteTransfer.setAttribute("aria-pressed", "true");
    showToast("情绪笔记已转存");
  });
  liveMuteButton.addEventListener("click", () => {
    liveMuted = !liveMuted;
    updateAILiveControls();
  });
  liveVideoButton.addEventListener("click", () => {
    liveVideoOff = !liveVideoOff;
    updateAILiveControls();
  });
  liveEndButton.addEventListener("click", endLiveToJournal);
  memoryStop.addEventListener("click", dismissMemoryFlow);
  journalSave.addEventListener("click", runJournalFiling);
  journalDelete.addEventListener("click", () => {
    journalDeleteConfirm.classList.add("visible");
    journalDeleteConfirm.setAttribute("aria-hidden", "false");
    window.setTimeout(() => journalDeleteCancel.focus({ preventScroll: true }), 120);
  });
  journalDeleteCancel.addEventListener("click", () => {
    closeDeleteConfirmation();
    journalDelete.focus({ preventScroll: true });
  });
  journalDeleteConfirmButton.addEventListener("click", dismissMemoryFlow);
  closeCommandButton.addEventListener("click", closeCommand);
  libraryCreateButton.addEventListener("click", openProposal);
  closeProposalButton.addEventListener("click", closeProposal);
  layerScrim.addEventListener("click", () => {
    closeProfile();
    if (commandLayer.classList.contains("visible")) closeCommand();
    if (proposalLayer.classList.contains("visible")) closeProposal();
  });
  commandForm.addEventListener("submit", (event) => {
    event.preventDefault();
    const value = commandInput.value.trim();
    if (value) runCommand(value);
  });
  $$("button", commandSuggestions).forEach((button) => {
    button.addEventListener("click", () => {
      commandInput.value = button.textContent;
      runCommand(button.textContent);
    });
  });

  $$("[data-proposal-action]").forEach((button) => {
    button.addEventListener("click", () => {
      const action = button.dataset.proposalAction;
      if (action === "preview") {
        closeProposal();
        selectRoute("library");
      } else if (action === "customize") {
        showToast("可以调整名称、范围、顺序、内容和视觉形式。");
      } else {
        closeProposal();
        showToast("日记已创建并固定。");
      }
    });
  });

  function navigatePrototype(state) {
    if (calendarView.classList.contains("is-visible")) closeCalendar({ restoreFocus: false });
    hideCalendarLaunch();
    closePrototypeNowMenu();
    closePrototypeActivityMenu();
    if (homeVoice.classList.contains("has-resumable-answer")) setDiningFollowupResume("");
    if (homeVoice.classList.contains("is-voice-task")) cancelVoiceTaskProcessor({ immediate: true });
    if (homeVoice.classList.contains("is-home-context")) closeHomeContextAnswer({ immediate: true, restoreFocus: false });
    if (homeVoice.classList.contains("is-dining-followup")) closeDiningFollowup({ immediate: true, restoreFocus: false });
    if (homeVoice.classList.contains("is-dining-taste")) closeDiningTasteFollowup({ immediate: true, restoreFocus: false });
    if (memoryFlow.classList.contains("visible")) {
      resetMemoryFlow();
      bottomSystem.classList.remove("hidden-for-activity");
    }
    if (aiLiveView.classList.contains("visible")) closeAILive({ restoreFocus: false });
    if (journalReaderView.classList.contains("visible")) closeJournalReader({ restoreNavigation: false });
    if (musicLibraryView.classList.contains("visible")) closeMusicLibrary({ restoreNavigation: false });
    if (collectionsView.classList.contains("visible")) closeCollectionsView({ restoreNavigation: false });
    if (activitySpace.classList.contains("active") && state === "activity") return;
    if (activitySpace.classList.contains("active") && state !== "activity") {
      exitActivity();
      window.setTimeout(() => navigatePrototype(state), 450);
      return;
    }

    closeSearch();
    closeProfile();
    if (commandLayer.classList.contains("visible")) closeCommand();
    if (proposalLayer.classList.contains("visible")) closeProposal();
    closeLibraryDetails({ restoreNavigation: false });
    bottomSystem.classList.remove("hidden-for-activity");

    if (state === "now") return selectRoute("now");
    if (state === "library") return selectRoute("library");
    if (state === "spaces") return selectRoute("spaces");
    if (state === "activity") {
      selectRoute("now");
      return window.setTimeout(enterActivity, 30);
    }
    if (state === "object") {
      selectRoute("library");
      return window.setTimeout(() => openObjectDetail("interface-sketch"), 30);
    }
    if (state === "gallery") {
      selectRoute("library");
      return setPrototypeActive("gallery");
    }
    if (state === "music") {
      selectRoute("library");
      return window.setTimeout(openMusicLibrary, 30);
    }
    if (state === "ai-command") {
      selectRoute("now");
      return window.setTimeout(openCommand, 30);
    }
    if (state === "live") {
      selectRoute("now");
      return window.setTimeout(openAILive, 30);
    }
    if (state === "generating") {
      selectRoute("now");
      return window.setTimeout(startJournalGeneration, 30);
    }
    if (state === "journal") {
      selectRoute("now");
      return window.setTimeout(showJournalDirect, 30);
    }
    if (state === "journal-open") {
      selectRoute("library");
      return window.setTimeout(() => openJournalReader({ animateFromGallery: false }), 30);
    }
    if (state === "journal-search") {
      selectRoute("library");
      return window.setTimeout(() => openJournalReader({ animateFromGallery: false, search: true }), 30);
    }
    if (state === "journal-filing") {
      selectRoute("now");
      return window.setTimeout(() => showJournalDirect("journal-filing"), 30);
    }
  }

  $$("[data-prototype]", prototypeNavigator).forEach((button) => {
    button.addEventListener("click", () => {
      if (button.dataset.prototype === "now") {
        if (prototypeNowMenu.classList.contains("open")) closePrototypeNowMenu({ restoreFocus: true });
        else openPrototypeNowMenu();
        return;
      }
      if (button.dataset.prototype === "activity") {
        if (prototypeActivityMenu.classList.contains("open")) closePrototypeActivityMenu({ restoreFocus: true });
        else openPrototypeActivityMenu();
        return;
      }
      closePrototypeNowMenu();
      closePrototypeActivityMenu();
      navigatePrototype(button.dataset.prototype);
    });
  });

  document.addEventListener("keydown", (event) => {
    if ((event.key === "Delete" || event.key === "Backspace") && journalReaderView.classList.contains("is-editing") && !event.target.isContentEditable) {
      const selectedVisual = $("[data-edit-visual].selected", journalReaderView);
      if (selectedVisual) {
        event.preventDefault();
        selectedVisual.hidden = true;
        selectedVisual.classList.remove("selected");
        readerDeleteSelection.disabled = true;
        return;
      }
    }
    if (event.key !== "Escape") return;
    if (privateNoteShareLayer.classList.contains("is-visible")) return closePrivateNoteShare();
    if (calendarView.classList.contains("is-visible")) return closeCalendar();
    if (calendarLaunchPill.classList.contains("is-visible")) return hideCalendarLaunch();
    if (prototypeNowMenu.classList.contains("open")) return closePrototypeNowMenu({ restoreFocus: true });
    if (prototypeActivityMenu.classList.contains("open")) return closePrototypeActivityMenu({ restoreFocus: true });
    if (deviceScreen.classList.contains("private-live-active")) return closePrivateLive();
    if (privateNoteReader.classList.contains("is-visible")) return closePrivateNoteReader();
    if (deviceScreen.classList.contains("voice-space-active")) return resetVoiceSpatialSpace();
    if (homeVoice.classList.contains("is-voice-task")) return cancelVoiceTaskProcessor();
    if (homeVoice.classList.contains("is-home-context")) return closeHomeContextAnswer();
    if (homeVoice.classList.contains("is-conversation-expanded")) return toggleDiningConversationHistory();
    if (homeVoice.classList.contains("is-dining-taste")) return closeDiningTasteFollowup();
    if (homeVoice.classList.contains("is-dining-followup")) return closeDiningFollowup();
    if (journalSearchLayer.classList.contains("visible")) return closeJournalSearch();
    if (journalJumpPanel.classList.contains("visible")) return closeJournalJump();
    if (journalDeleteConfirm.classList.contains("visible")) return closeDeleteConfirmation();
    if (memoryFlow.classList.contains("visible")) return dismissMemoryFlow();
    if (aiLiveView.classList.contains("visible")) return closeAILive();
    if (activitySpace.classList.contains("active")) return exitActivity();
    if (journalReaderView.classList.contains("visible")) return closeJournalReader();
    if (musicLibraryView.classList.contains("visible")) return closeMusicLibrary();
    if (collectionsView.classList.contains("visible")) return closeCollectionsView();
    if (objectDetailView.classList.contains("visible") || galleryDetailView.classList.contains("visible") || libraryLensView.classList.contains("visible")) return closeLibraryDetails();
    if (searchLayer.classList.contains("visible")) return closeSearch();
    if (proposalLayer.classList.contains("visible")) return closeProposal();
    if (commandLayer.classList.contains("visible")) return closeCommand();
    closeProfile();
  });
})();
