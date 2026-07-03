/* Voxly landing - theme toggle + scroll reveal. No dependencies. */
(function () {
  "use strict";

  var root = document.documentElement;

  /* ---------------- Theme (icon-button dark/light toggle) ----------------
     Defaults to Auto (no data-theme -> follows the OS via prefers-color-scheme).
     The button flips between light and dark; the choice is intentionally NOT
     persisted, so a refresh returns to Auto. */
  var themeBtn = document.querySelector(".theme-btn");
  var darkQuery = window.matchMedia("(prefers-color-scheme: dark)");
  var reduceMotion =
    window.matchMedia &&
    window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  /* Resolved theme actually on screen right now: manual override if set,
     otherwise whatever the OS prefers. */
  function effectiveTheme() {
    var attr = root.getAttribute("data-theme");
    if (attr === "light" || attr === "dark") return attr;
    return darkQuery.matches ? "dark" : "light";
  }

  /* Mirror the effective theme onto the button so CSS shows the right icon
     (sun while dark -> click for light, moon while light -> click for dark). */
  function reflect() {
    if (themeBtn) themeBtn.setAttribute("data-effective", effectiveTheme());
  }

  function apply(choice) {
    root.setAttribute("data-theme", choice);
    reflect();
  }

  /* Crossfade through the View Transitions API when available: one
     GPU-composited fade of the whole page instead of animating color on many
     elements each frame (which stutters with the nav backdrop blur). */
  function setTheme(choice) {
    if (document.startViewTransition && !reduceMotion) {
      document.startViewTransition(function () {
        apply(choice);
      });
    } else {
      apply(choice);
    }
  }

  reflect();

  if (themeBtn) {
    themeBtn.addEventListener("click", function () {
      setTheme(effectiveTheme() === "dark" ? "light" : "dark");
    });
  }

  /* While still in Auto, keep the icon correct if the OS theme changes. */
  darkQuery.addEventListener("change", function () {
    if (!root.getAttribute("data-theme")) reflect();
  });

  /* ---------------- Scroll reveal ---------------- */
  var reveals = Array.prototype.slice.call(document.querySelectorAll(".reveal"));
  var reduce =
    window.matchMedia &&
    window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  if (reduce || !("IntersectionObserver" in window)) {
    reveals.forEach(function (el) {
      el.classList.add("is-in");
    });
  } else {
    var io = new IntersectionObserver(
      function (entries) {
        entries.forEach(function (entry) {
          if (entry.isIntersecting) {
            entry.target.classList.add("is-in");
            io.unobserve(entry.target);
          }
        });
      },
      { threshold: 0.3 }
    );
    reveals.forEach(function (el) {
      io.observe(el);
    });
  }
})();
