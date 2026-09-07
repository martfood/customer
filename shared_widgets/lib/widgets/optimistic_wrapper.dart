import 'package:flutter/material.dart';

/// A wrapper widget to handle optimistic UI updates.
/// It takes an [action] that returns a Future and [onSuccess]/[onError] callbacks.
class OptimisticWrapper extends StatefulWidget {
  final Widget child;
  final Widget? loadingPlaceholder;
  final Future<void> Function() action;
  final VoidCallback? onSuccess;
  final Function(Object)? onError;

  const OptimisticWrapper({
    super.key,
    required this.child,
    required this.action,
    this.loadingPlaceholder,
    this.onSuccess,
    this.onError,
  });

  @override
  State<OptimisticWrapper> createState() => _OptimisticWrapperState();
}

class _OptimisticWrapperState extends State<OptimisticWrapper> {
  bool _isOptimistic = false;

  void _triggerAction() async {
    setState(() {
      _isOptimistic = true;
    });

    try {
      await widget.action();
      if (mounted) {
        widget.onSuccess?.call();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isOptimistic = false;
        });
        widget.onError?.call(e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // In a real implementation, this would be more complex, 
    // potentially swapping between child and loadingPlaceholder 
    // or just providing the trigger function via a builder.
    return GestureDetector(
      onTap: _triggerAction,
      child: _isOptimistic ? (widget.loadingPlaceholder ?? widget.child) : widget.child,
    );
  }
}
