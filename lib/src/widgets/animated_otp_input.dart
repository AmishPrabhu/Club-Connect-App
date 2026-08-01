import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AnimatedOtpInput extends StatefulWidget {
  final TextEditingController controller;
  final int length;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onCompleted;
  final bool isError;
  final bool isSuccess;
  final bool isVerifying;

  const AnimatedOtpInput({
    super.key,
    required this.controller,
    this.length = 6,
    this.onChanged,
    this.onCompleted,
    this.isError = false,
    this.isSuccess = false,
    this.isVerifying = false,
  });

  @override
  State<AnimatedOtpInput> createState() => _AnimatedOtpInputState();
}

class _AnimatedOtpInputState extends State<AnimatedOtpInput>
    with TickerProviderStateMixin {
  late FocusNode _focusNode;

  late AnimationController _borderRotateController;
  late AnimationController _mergeController;
  late AnimationController _analyzingController;
  late AnimationController _flipController;
  late AnimationController _shakeController;

  late Animation<double> _mergeAnimation;
  late Animation<double> _flipAnimation;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();

    _focusNode.addListener(() {
      if (mounted) setState(() {});
    });

    // 1. Continuous 360 Border Beam Rotation
    _borderRotateController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();

    // 2. 3D Card Merge Fold Controller (Relaxed 750ms fluid merge)
    _mergeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );
    _mergeAnimation = CurvedAnimation(
      parent: _mergeController,
      curve: Curves.easeInOutCubic,
    );

    // 3. Analyzing 3D Wave Tilt Controller (Calm 1600ms cycle)
    _analyzingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );

    // 4. Result Card 180° 3D Flip Controller (700ms elastic flip)
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _flipAnimation = CurvedAnimation(
      parent: _flipController,
      curve: Curves.easeOutBack,
    );

    // 5. Error Shake Controller
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );

    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -12.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -12.0, end: 12.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 12.0, end: -8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8.0, end: -4.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -4.0, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(
      parent: _shakeController,
      curve: Curves.easeInOut,
    ));

    widget.controller.addListener(_onTextChanged);

    // Auto focus on start if not merged
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !widget.isVerifying && !widget.isSuccess) {
        _focusNode.requestFocus();
      }
    });

    _syncAnimationStates();
  }

  void _onTextChanged() {
    final text = widget.controller.text;
    widget.onChanged?.call(text);

    if (text.length == widget.length) {
      _focusNode.unfocus();
      FocusScope.of(context).unfocus();
      widget.onCompleted?.call(text);
    }
    _syncAnimationStates();
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant AnimatedOtpInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncAnimationStates(oldWidget: oldWidget);
  }

  void _syncAnimationStates({AnimatedOtpInput? oldWidget}) {
    final isMerged = widget.isVerifying || widget.isSuccess || widget.isError;

    if (isMerged) {
      if (_focusNode.hasFocus) {
        _focusNode.unfocus();
        FocusScope.of(context).unfocus();
      }

      if (!_mergeController.isCompleted && _mergeController.status != AnimationStatus.forward) {
        _mergeController.forward();
      }

      if (widget.isVerifying && !widget.isSuccess && !widget.isError) {
        if (!_analyzingController.isAnimating) {
          _analyzingController.repeat(reverse: true);
        }
      } else {
        _analyzingController.stop();
      }

      // Trigger 3D flip when success or error occurs!
      if (widget.isSuccess || widget.isError) {
        if (_flipController.status != AnimationStatus.forward && _flipController.value < 1.0) {
          _flipController.forward(from: 0.0);
        }
      }

      if (widget.isError && oldWidget?.isError != true) {
        _shakeController.forward(from: 0.0);

        // Auto-reset to 6 empty boxes after 1.6s relaxed error display
        Future.delayed(const Duration(milliseconds: 1600), () {
          if (mounted) {
            widget.controller.clear();
            widget.onChanged?.call('');
            _flipController.reverse();
            _mergeController.reverse().then((_) {
              if (mounted) {
                _focusNode.requestFocus();
              }
            });
          }
        });
      }
    } else {
      if (_mergeController.value > 0) {
        _mergeController.reverse();
      }
      _analyzingController.stop();
      _flipController.reset();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _focusNode.dispose();
    _borderRotateController.dispose();
    _mergeController.dispose();
    _analyzingController.dispose();
    _flipController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final text = widget.controller.text;
    final isMerged = widget.isVerifying || widget.isSuccess || widget.isError;
    final isFocused = _focusNode.hasFocus;
    final activeIndex = text.length.clamp(0, widget.length - 1);
    final middleIndex = widget.length ~/ 2;

    const activeColor = Color(0xFFE53E3E);
    const successColor = Color(0xFF10B981);
    const errorColor = Color(0xFFEF4444);

    return AnimatedBuilder(
      animation: Listenable.merge([
        _shakeAnimation,
        _mergeAnimation,
        _analyzingController,
        _flipAnimation,
      ]),
      builder: (context, child) {
        final shakeX = _shakeAnimation.value;
        final mergeProgress = _mergeAnimation.value;
        final flipProgress = _flipAnimation.value;

        return Transform.translate(
          offset: Offset(shakeX, 0),
          child: GestureDetector(
            onTap: () {
              if (!widget.isVerifying && !widget.isSuccess) {
                _focusNode.requestFocus();
              }
            },
            behavior: HitTestBehavior.opaque,
            child: Center(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final totalWidth = constraints.maxWidth;
                  const double gap = 8.0;
                  final double itemWidth = ((totalWidth - ((widget.length - 1) * gap)) / widget.length)
                      .clamp(38.0, 52.0);
                  const double itemHeight = 60.0;
                  final double stepOffset = itemWidth + gap;

                  // Dead center target X for all cards when merged!
                  final double containerCenterLeft = ((widget.length - 1) * stepOffset) / 2.0;

                  return SizedBox(
                    height: itemHeight,
                    width: (widget.length * itemWidth) + ((widget.length - 1) * gap),
                    child: Stack(
                      alignment: Alignment.centerLeft,
                      clipBehavior: Clip.none,
                      children: [
                        // Invisible Native Master TextField
                        Positioned.fill(
                          child: Opacity(
                            opacity: 0.0,
                            child: TextField(
                              controller: widget.controller,
                              focusNode: _focusNode,
                              keyboardType: TextInputType.number,
                              maxLength: widget.length,
                              autofillHints: const [AutofillHints.oneTimeCode],
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(widget.length),
                              ],
                              decoration: const InputDecoration(
                                counterText: '',
                                border: InputBorder.none,
                              ),
                              enabled: !widget.isVerifying && !widget.isSuccess,
                            ),
                          ),
                        ),

                        // Visual 3D OTP Cards Deck
                        ...List.generate(widget.length, (index) {
                          final char = index < text.length ? text[index] : '';
                          final isActiveBox = isFocused && (index == activeIndex || (text.length == widget.length && index == widget.length - 1));
                          final isFilled = char.isNotEmpty;
                          final activeBorder = (isActiveBox || isFilled) && mergeProgress < 0.3;

                          final isMiddleBox = index == middleIndex;

                          // Unmerged position = index * stepOffset
                          final double unmergedLeft = index * stepOffset;
                          // Merged position = ALL cards slide smoothly into dead center left!
                          final double currentLeft = unmergedLeft + (containerCenterLeft - unmergedLeft) * mergeProgress;

                          // 3D Card Fold Y-Rotation angle
                          final double foldYAngle = (index - middleIndex) * 0.4 * mergeProgress;

                          // Smooth quad opacity decay so side cards dissolve right as they touch center!
                          final double cardOpacity = isMiddleBox
                              ? 1.0
                              : (1.0 - math.pow(mergeProgress, 2.0)).clamp(0.0, 1.0);

                          final double cardScale = isMiddleBox
                              ? 1.0
                              : (1.0 - mergeProgress * 0.4).clamp(0.1, 1.0);

                          // 3D Flip angle & analyzing tilt wave for center box
                          final double flipAngle = isMiddleBox ? flipProgress * math.pi : 0.0;
                          final double analyzingWave = (isMiddleBox && widget.isVerifying && flipProgress == 0.0)
                              ? math.sin(_analyzingController.value * math.pi * 2) * 0.12
                              : 0.0;

                          if (cardOpacity <= 0.001) {
                            return const SizedBox.shrink();
                          }

                          return Positioned(
                            left: currentLeft,
                            top: 0,
                            child: Transform(
                              alignment: Alignment.center,
                              transform: Matrix4.identity()
                                ..setEntry(3, 2, 0.0015) // Perspective 3D depth
                                ..rotateY(foldYAngle + flipAngle + analyzingWave)
                                ..scale(cardScale),
                              child: Opacity(
                                opacity: cardOpacity,
                                child: _OtpCardItem(
                                  char: char,
                                  width: itemWidth,
                                  height: itemHeight,
                                  isDark: isDark,
                                  activeBorder: activeBorder,
                                  isMerged: mergeProgress > 0.5,
                                  isMiddleBox: isMiddleBox,
                                  isVerifying: widget.isVerifying,
                                  isSuccess: widget.isSuccess,
                                  isError: widget.isError,
                                  flipProgress: flipProgress,
                                  borderRotateController: _borderRotateController,
                                  activeColor: activeColor,
                                  successColor: successColor,
                                  errorColor: errorColor,
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class _OtpCardItem extends StatelessWidget {
  final String char;
  final double width;
  final double height;
  final bool isDark;
  final bool activeBorder;
  final bool isMerged;
  final bool isMiddleBox;
  final bool isVerifying;
  final bool isSuccess;
  final bool isError;
  final double flipProgress;
  final AnimationController borderRotateController;
  final Color activeColor;
  final Color successColor;
  final Color errorColor;

  const _OtpCardItem({
    required this.char,
    required this.width,
    required this.height,
    required this.isDark,
    required this.activeBorder,
    required this.isMerged,
    required this.isMiddleBox,
    required this.isVerifying,
    required this.isSuccess,
    required this.isError,
    required this.flipProgress,
    required this.borderRotateController,
    required this.activeColor,
    required this.successColor,
    required this.errorColor,
  });

  @override
  Widget build(BuildContext context) {
    const double borderRadius = 14.0;
    final bool isFlippedPastHalf = flipProgress >= 0.45;

    // Card background color logic
    Color bgColor;
    if (isMerged && isMiddleBox) {
      if (isFlippedPastHalf || isSuccess || isError) {
        if (isSuccess) {
          bgColor = successColor;
        } else if (isError) {
          bgColor = errorColor;
        } else {
          bgColor = isDark ? const Color(0xFF27272A) : Colors.grey.shade100;
        }
      } else {
        bgColor = isDark ? const Color(0xFF27272A) : Colors.grey.shade100;
      }
    } else {
      bgColor = isDark ? const Color(0xFF18181B) : Colors.grey.shade100;
    }

    final Color staticBorderColor = isDark ? const Color(0xFF27272A) : Colors.grey.shade300;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: activeBorder
            ? [
                BoxShadow(
                  color: activeColor.withOpacity(0.25),
                  blurRadius: 10,
                  spreadRadius: 0,
                )
              ]
            : isMerged && isMiddleBox
                ? [
                    BoxShadow(
                      color: (isSuccess
                              ? successColor
                              : isError
                                  ? errorColor
                                  : activeColor)
                          .withOpacity(0.4),
                      blurRadius: 16,
                      spreadRadius: 2,
                    )
                  ]
                : null,
        border: !activeBorder && !(isMerged && isMiddleBox)
            ? Border.all(color: staticBorderColor, width: 1.2)
            : null,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Isolated RepaintBoundary for 360 Rotating Conic Beam
          if (activeBorder)
            Positioned.fill(
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: borderRotateController,
                  builder: (context, child) {
                    return CustomPaint(
                      painter: _RotatingBorderBeamPainter(
                        angle: borderRotateController.value * 2 * math.pi,
                        color: activeColor,
                        borderRadius: borderRadius,
                        strokeWidth: 2.0,
                      ),
                    );
                  },
                ),
              ),
            ),

          // Central Card Contents when merged
          if (isMerged && isMiddleBox)
            (isFlippedPastHalf || isSuccess || isError)
                ? Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.rotationY(math.pi), // Un-mirror flipped text/icon
                    child: _buildResultBadge(),
                  )
                : _buildAnalyzingLoader(),

          // Display character digit when unmerged
          if (!isMerged)
            Center(
              child: Text(
                char,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAnalyzingLoader() {
    return SizedBox(
      width: 24,
      height: 24,
      child: CircularProgressIndicator(
        strokeWidth: 2.5,
        valueColor: AlwaysStoppedAnimation<Color>(
          isDark ? Colors.white : Colors.black,
        ),
      ),
    );
  }

  Widget _buildResultBadge() {
    if (isSuccess) {
      return const Icon(
        Icons.check_rounded,
        color: Colors.white,
        size: 32,
      );
    } else if (isError) {
      return const Icon(
        Icons.close_rounded,
        color: Colors.white,
        size: 32,
      );
    }
    return _buildAnalyzingLoader();
  }
}

/// Ultra-smooth Rotating Conic Border Beam Painter
class _RotatingBorderBeamPainter extends CustomPainter {
  final double angle;
  final Color color;
  final double borderRadius;
  final double strokeWidth;

  _RotatingBorderBeamPainter({
    required this.angle,
    required this.color,
    required this.borderRadius,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final halfStroke = strokeWidth / 2.0;
    final rect = Offset(halfStroke, halfStroke) &
        Size(size.width - strokeWidth, size.height - strokeWidth);
    final rrect = RRect.fromRectAndRadius(
      rect,
      Radius.circular(math.max(0, borderRadius - halfStroke)),
    );

    final paint = Paint()
      ..shader = SweepGradient(
        colors: [
          Colors.transparent,
          Colors.transparent,
          color.withOpacity(0.3),
          color,
        ],
        stops: const [0.0, 0.55, 0.85, 1.0],
        transform: GradientRotation(angle),
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant _RotatingBorderBeamPainter oldDelegate) {
    return oldDelegate.angle != angle ||
        oldDelegate.color != color ||
        oldDelegate.borderRadius != borderRadius ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
