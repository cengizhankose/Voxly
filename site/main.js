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

  apply(currentChoice());

  segButtons.forEach(function (btn) {
    btn.addEventListener("click", function () {
      var choice = btn.getAttribute("data-theme-set");
      try {
        if (choice === "auto") localStorage.removeItem(STORAGE_KEY);
        else localStorage.setItem(STORAGE_KEY, choice);
      } catch (e) {}
      apply(choice);
    });
  });

  /* Enable the 350ms color transition only after first paint, so toggling
     animates but the initial load does not flash. */
  requestAnimationFrame(function () {
    requestAnimationFrame(function () {
      root.classList.add("theme-anim");
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
