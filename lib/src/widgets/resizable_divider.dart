import 'package:flutter/material.dart';

class ResizableDivider extends StatefulWidget {
  final Axis direction;
  final double initialSize;
  final double minSize;
  final double maxSize;
  final ValueChanged<double>? onResize;

  const ResizableDivider({
    super.key,
    this.direction = Axis.horizontal,
    this.initialSize = 0.7,
    this.minSize = 0.2,
    this.maxSize = 0.9,
    this.onResize,
  });

  @override
  State<ResizableDivider> createState() => _ResizableDividerState();
}

class _ResizableDividerState extends State<ResizableDivider> {
  late double _size;
  bool _isHovering = false;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _size = widget.initialSize;
  }

  @override
  Widget build(BuildContext context) {
    final isHorizontal = widget.direction == Axis.horizontal;

    return MouseRegion(
      cursor: isHorizontal
          ? SystemMouseCursors.resizeRow
          : SystemMouseCursors.resizeColumn,
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onPanStart: (_) => setState(() => _isDragging = true),
        onPanEnd: (_) => setState(() => _isDragging = false),
        onPanCancel: () => setState(() => _isDragging = false),
        onPanUpdate: (details) {
          final box = context.findRenderObject() as RenderBox?;
          if (box == null) return;

          final parentBox = box.parent as RenderBox?;
          if (parentBox == null) return;

          final parentSize = parentBox.size;
          final localDelta = isHorizontal ? details.delta.dy : details.delta.dx;

          setState(() {
            if (isHorizontal) {
              _size += localDelta / parentSize.height;
            } else {
              _size += localDelta / parentSize.width;
            }
            _size = _size.clamp(widget.minSize, widget.maxSize);
            widget.onResize?.call(_size);
          });
        },
        child: Container(
          width: isHorizontal ? double.infinity : 8,
          height: isHorizontal ? 8 : double.infinity,
          color: Colors.transparent,
        ),
      ),
    );
  }
}
