# Swipe Back

A simple, drop-in replacement for Flutter's default page transitions that enables an iOS-style back swipe gesture from **anywhere** on the screen, not just the left edge. 

![Swipe Back Demo](https://github.com/user-attachments/assets/3213b346-3940-4abb-abe8-1ade44fe60e6)

## Features

- **Full-Screen Swipe** — Works from anywhere on the screen.
- **Native iOS Feel** — Pixel-perfect transitions, parallax effects, and spring physics.
- **Drop-in Ready** — Easy to integrate into your app's theme.
- **RTL & Fullscreen Dialog Support** — Complete language direction and modal support.

## Installation

```yaml
dependencies:
  swipe_back: ^<latest_version>
```

## Usage

The easiest way to use `swipe_back` is to set it as the default page transition builder in your app's `ThemeData`:

```dart
import 'package:swipe_back/swipe_back.dart';

MaterialApp(
  theme: ThemeData(
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.iOS: SwipeBackPageTransitionsBuilder(),
        TargetPlatform.android: SwipeBackPageTransitionsBuilder(),
      },
    ),
  ),
  home: const HomeScreen(),
)
```

Now, every `Navigator.push` or `MaterialPageRoute` will automatically support the full-screen back gesture!

### Direct Usage

You can also use it for specific routes using `CupertinoPageRoute` from the package:

```dart
import 'package:swipe_back/swipe_back.dart';

Navigator.push(
  context,
  CupertinoPageRoute(
    builder: (context) => const DetailScreen(),
  ),
);
```

## License & Attribution

This package builds upon Flutter's native Cupertino route transitions (BSD 3-Clause). 
Licensed under the [MIT License](LICENSE).
