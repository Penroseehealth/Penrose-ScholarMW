/// Non-web no-op: there is no DOM element to configure.
void configureBiologyLabIframe(Object element, String url) {
  // Intentionally empty — platform views only exist on web.
}

/// Non-web no-op: there is no parent frame to receive exit requests from.
void Function() listenForBioLabExit(void Function() onExit) => () {};
