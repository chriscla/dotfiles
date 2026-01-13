export default {
  // 1. Route to "Work" profile in Google Chrome by default
  defaultBrowser: {
    name: "Google Chrome",
    profile: "Work",
  },

  options: {
    // 3. No logging, rewriting, or UI
    hideIcon: true,        // Hides the icon from the menu bar
    checkForUpdates: false, // Disables update notifications
    logRequests: false,    // Disables logging
  },

  handlers: [
    {
      // 2. Route requests to any sub-domain of at2311.com
      match: "*.at2311.com/*",
      browser: {
        name: "Google Chrome",
        profile: "Chris",
      },
    },
  ],
};
