/* Voxly landing - theme toggle + scroll reveal. No dependencies. */
(function () {
  "use strict";

  var STORAGE_KEY = "voxly-signal-theme";
  var root = document.documentElement;

  /* ---------------- Theme (Light / Auto / Dark) ---------------- */
  var segButtons = Array.prototype.slice.call(
    document.querySelectorAll("[data-theme-set]")
  );

  function currentChoice() {
    try {
      var t = localStorage.getItem(STORAGE_KEY);
      return t === "light" || t === "dark" ? t : "auto";
    } catch (e) {
      return "auto";
    }
  }

  var reduceMotion =
    window.matchMedia &&
    window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  function apply(choice) {
    if (choice === "auto") {
      root.removeAttribute("data-theme");
    } else {
      root.setAttribute("data-theme", choice);
    }
    segButtons.forEach(function (btn) {
      var pressed = btn.getAttribute("data-theme-set") === choice;
      btn.setAttribute("aria-pressed", pressed ? "true" : "false");
    });
  }

  /* Swap theme. When available, crossfade through the View Transitions API:
     a single GPU-composited fade of the whole page, instead of animating
     background-color/color on dozens of elements every frame (which stutters,
     especially with the nav's backdrop blur). Falls back to an instant swap. */
  function setTheme(choice) {
    if (document.startViewTransition && !reduceMotion) {
      document.startViewTransition(function () {
        apply(choice);
      });
    } else {
      apply(choice);
    }
  }

  apply(currentChoice());

  segButtons.forEach(function (btn) {
    btn.addEventListener("click", function () {
      var choice = btn.getAttribute("data-theme-set");
      try {
        if (choice === "auto") localStorage.removeItem(STORAGE_KEY);
        else localStorage.setItem(STORAGE_KEY, choice);
      } catch (e) {}
      setTheme(choice);
    });
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
