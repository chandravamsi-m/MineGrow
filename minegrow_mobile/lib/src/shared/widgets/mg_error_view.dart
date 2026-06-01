import 'package:flutter/material.dart';
import 'package:flutter_app_utilities/flutter_app_utilities.dart';

import '../../core/network/api_exception.dart';
import 'mg_widgets.dart';

/// Renders the right error experience for a failed async load.
///
/// Connectivity failures get the dedicated [NoInternetScreen], server (5xx)
/// failures get [NoServerConnectionScreen], and everything else falls back to
/// the branded [MGFriendlyState] using the supplied [fallbackIcon],
/// [fallbackTitle], and [fallbackMessage].
///
/// The blocking screens are rendered with `wrapWithScaffold: false` so they
/// embed inside each screen's existing [MGScaffold] body. Those screens center
/// their content with an expanding layout, which would overflow inside an
/// unbounded scroll view (the app renders `.when()` results inside
/// `SingleChildScrollView`/`ListView`). [_BoundedFullScreen] gives them a
/// bounded height in that case so they lay out correctly.
// @preview
// class MGErrorViewPreview extends StatelessWidget {
//   const MGErrorViewPreview({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return mgErrorView(error: ApiException(message: 'Test'), fallbackIcon: Icons.error, fallbackTitle: 'Test', fallbackMessage: 'Test');
//   }
// }
Widget mgErrorView({
  required Object error,
  VoidCallback? onRetry,
  required IconData fallbackIcon,
  required String fallbackTitle,
  required String fallbackMessage,
}) {
  if (error is ApiException) {
    if (error.isConnectionError) {
      return _BoundedFullScreen(
        child: NoInternetScreen(wrapWithScaffold: false, onRetry: onRetry),
      );
    }
    if (error.isServerError) {
      return _BoundedFullScreen(
        child:
            NoServerConnectionScreen(wrapWithScaffold: false, onRetry: onRetry),
      );
    }
  }

  return MGFriendlyState(
    icon: fallbackIcon,
    title: fallbackTitle,
    message: fallbackMessage,
    actionLabel: onRetry == null ? null : 'Retry',
    onAction: onRetry,
  );
}

/// Ensures a full-screen, center-aligned [child] gets a bounded height even
/// when placed inside an unbounded scroll view.
class _BoundedFullScreen extends StatelessWidget {
  const _BoundedFullScreen({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // A finite parent (e.g. an Expanded or fixed-height region) can size
        // the centered child directly.
        if (constraints.maxHeight.isFinite) {
          return child;
        }
        // Inside an unbounded scroll view: give the centered content a
        // sensible bounded height so it lays out and reads as full-screen.
        return SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.6,
          child: child,
        );
      },
    );
  }
}
