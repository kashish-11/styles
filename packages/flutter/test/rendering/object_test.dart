// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'rendering_tester.dart';

void main() {
  test('ensure frame is scheduled for markNeedsSemanticsUpdate', () {
    // Initialize all bindings because owner.flushSemantics() requires a window
    renderer;

    final TestRenderObject renderObject = TestRenderObject();
    int onNeedVisualUpdateCallCount = 0;
    final PipelineOwner owner = PipelineOwner(onNeedVisualUpdate: () {
      onNeedVisualUpdateCallCount +=1;
    });
    owner.ensureSemantics();
    renderObject.attach(owner);
    renderObject.layout(const BoxConstraints.tightForFinite());  // semantics are only calculated if layout information is up to date.
    owner.flushSemantics();

    expect(onNeedVisualUpdateCallCount, 1);
    renderObject.markNeedsSemanticsUpdate();
    expect(onNeedVisualUpdateCallCount, 2);
  });

  test('detached RenderObject does not do semantics', () {
    final TestRenderObject renderObject = TestRenderObject();
    expect(renderObject.attached, isFalse);
    expect(renderObject.describeSemanticsConfigurationCallCount, 0);

    renderObject.markNeedsSemanticsUpdate();
    expect(renderObject.describeSemanticsConfigurationCallCount, 0);
  });

  test('ensure errors processing render objects are well formatted', () {
    late FlutterErrorDetails errorDetails;
    final FlutterExceptionHandler? oldHandler = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      errorDetails = details;
    };
    final PipelineOwner owner = PipelineOwner();
    final TestThrowingRenderObject renderObject = TestThrowingRenderObject();
    try {
      renderObject.attach(owner);
      renderObject.layout(const BoxConstraints());
    } finally {
      FlutterError.onError = oldHandler;
    }

    expect(errorDetails, isNotNull);
    expect(errorDetails.stack, isNotNull);
    // Check the ErrorDetails without the stack trace
    final List<String> lines =  errorDetails.toString().split('\n');
    // The lines in the middle of the error message contain the stack trace
    // which will change depending on where the test is run.
    expect(lines.length, greaterThan(8));
    expect(
      lines.take(4).join('\n'),
      equalsIgnoringHashCodes(
        '══╡ EXCEPTION CAUGHT BY RENDERING LIBRARY ╞══════════════════════\n'
        'The following assertion was thrown during performLayout():\n'
        'TestThrowingRenderObject does not support performLayout.\n',
      ),
    );

    expect(
      lines.getRange(lines.length - 8, lines.length).join('\n'),
      equalsIgnoringHashCodes(
        '\n'
        'The following RenderObject was being processed when the exception was fired:\n'
        '  TestThrowingRenderObject#00000 NEEDS-PAINT:\n'
        '  parentData: MISSING\n'
        '  constraints: BoxConstraints(unconstrained)\n'
        'This RenderObject has no descendants.\n'
        '═════════════════════════════════════════════════════════════════\n',
      ),
    );
  });

  test('ContainerParentDataMixin requires nulled out pointers to siblings before detach', () {
    expect(() => TestParentData().detach(), isNot(throwsAssertionError));

    final TestParentData data1 = TestParentData()
      ..nextSibling = RenderOpacity()
      ..previousSibling = RenderOpacity();
    expect(() => data1.detach(), throwsAssertionError);

    final TestParentData data2 = TestParentData()
      ..previousSibling = RenderOpacity();
    expect(() => data2.detach(), throwsAssertionError);

    final TestParentData data3 = TestParentData()
      ..nextSibling = RenderOpacity();
    expect(() => data3.detach(), throwsAssertionError);
  });

  test('RenderObject.getTransformTo asserts is argument is not descendant', () {
    final PipelineOwner owner = PipelineOwner();
    final TestRenderObject renderObject1 = TestRenderObject();
    renderObject1.attach(owner);
    final TestRenderObject renderObject2 = TestRenderObject();
    renderObject2.attach(owner);
    expect(() => renderObject1.getTransformTo(renderObject2), throwsAssertionError);
  });

  test('PaintingContext.pushClipRect reuses the layer', () {
    _testPaintingContextLayerReuse<ClipRectLayer>((PaintingContextCallback painter, PaintingContext context, Offset offset, Layer? oldLayer) {
      return context.pushClipRect(true, offset, Rect.zero, painter, oldLayer: oldLayer as ClipRectLayer?);
    });
  });

  test('PaintingContext.pushClipRRect reuses the layer', () {
    _testPaintingContextLayerReuse<ClipRRectLayer>((PaintingContextCallback painter, PaintingContext context, Offset offset, Layer? oldLayer) {
      return context.pushClipRRect(true, offset, Rect.zero, RRect.fromRectAndRadius(Rect.zero, const Radius.circular(1.0)), painter, oldLayer: oldLayer as ClipRRectLayer?);
    });
  });

  test('PaintingContext.pushClipPath reuses the layer', () {
    _testPaintingContextLayerReuse<ClipPathLayer>((PaintingContextCallback painter, PaintingContext context, Offset offset, Layer? oldLayer) {
      return context.pushClipPath(true, offset, Rect.zero, Path(), painter, oldLayer: oldLayer as ClipPathLayer?);
    });
  });

  test('PaintingContext.pushColorFilter reuses the layer', () {
    _testPaintingContextLayerReuse<ColorFilterLayer>((PaintingContextCallback painter, PaintingContext context, Offset offset, Layer? oldLayer) {
      return context.pushColorFilter(offset, const ColorFilter.mode(Color.fromRGBO(0, 0, 0, 1.0), BlendMode.clear), painter, oldLayer: oldLayer as ColorFilterLayer?);
    });
  });

  test('PaintingContext.pushTransform reuses the layer', () {
    _testPaintingContextLayerReuse<TransformLayer>((PaintingContextCallback painter, PaintingContext context, Offset offset, Layer? oldLayer) {
      return context.pushTransform(true, offset, Matrix4.identity(), painter, oldLayer: oldLayer as TransformLayer?);
    });
  });

  test('PaintingContext.pushOpacity reuses the layer', () {
    _testPaintingContextLayerReuse<OpacityLayer>((PaintingContextCallback painter, PaintingContext context, Offset offset, Layer? oldLayer) {
      return context.pushOpacity(offset, 100, painter, oldLayer: oldLayer as OpacityLayer?);
    });
  });

  test('RenderObject.dispose sets debugDisposed to true', () {
    final TestRenderObject renderObject = TestRenderObject();
    expect(renderObject.debugDisposed, false);
    renderObject.dispose();
    expect(renderObject.debugDisposed, true);
    expect(renderObject.toStringShort(), contains('DISPOSED'));
  });

  test('Leader layer can switch to a different render object within one frame', () {
    List<FlutterErrorDetails?>? caughtErrors;
    renderer.onErrors = () {
      caughtErrors = renderer.takeAllFlutterErrorDetails().toList();
    };

    final LayerLink layerLink = LayerLink();
    // renderObject1 paints the leader layer first.
    final LeaderLayerRenderObject renderObject1 = LeaderLayerRenderObject();
    renderObject1.layerLink = layerLink;
    renderObject1.attach(renderer.pipelineOwner);
    final OffsetLayer rootLayer1 = OffsetLayer();
    rootLayer1.attach(renderObject1);
    renderObject1.scheduleInitialPaint(rootLayer1);
    renderObject1.layout(const BoxConstraints.tightForFinite());

    final LeaderLayerRenderObject renderObject2 = LeaderLayerRenderObject();
    final OffsetLayer rootLayer2 = OffsetLayer();
    rootLayer2.attach(renderObject2);
    renderObject2.attach(renderer.pipelineOwner);
    renderObject2.scheduleInitialPaint(rootLayer2);
    renderObject2.layout(const BoxConstraints.tightForFinite());
    renderer.pumpCompleteFrame();

    // Swap the layer link to renderObject2 in the same frame
    renderObject1.layerLink = null;
    renderObject1.markNeedsPaint();
    renderObject2.layerLink = layerLink;
    renderObject2.markNeedsPaint();
    renderer.pumpCompleteFrame();

    // Swap the layer link to renderObject1 in the same frame
    renderObject1.layerLink = layerLink;
    renderObject1.markNeedsPaint();
    renderObject2.layerLink = null;
    renderObject2.markNeedsPaint();
    renderer.pumpCompleteFrame();

    renderer.onErrors = null;
    expect(caughtErrors, isNull);
  });

  test('Leader layer append to two render objects does crash', () {
    List<FlutterErrorDetails?>? caughtErrors;
    renderer.onErrors = () {
      caughtErrors = renderer.takeAllFlutterErrorDetails().toList();
    };
    final LayerLink layerLink = LayerLink();
    // renderObject1 paints the leader layer first.
    final LeaderLayerRenderObject renderObject1 = LeaderLayerRenderObject();
    renderObject1.layerLink = layerLink;
    renderObject1.attach(renderer.pipelineOwner);
    final OffsetLayer rootLayer1 = OffsetLayer();
    rootLayer1.attach(renderObject1);
    renderObject1.scheduleInitialPaint(rootLayer1);
    renderObject1.layout(const BoxConstraints.tightForFinite());

    final LeaderLayerRenderObject renderObject2 = LeaderLayerRenderObject();
    renderObject2.layerLink = layerLink;
    final OffsetLayer rootLayer2 = OffsetLayer();
    rootLayer2.attach(renderObject2);
    renderObject2.attach(renderer.pipelineOwner);
    renderObject2.scheduleInitialPaint(rootLayer2);
    renderObject2.layout(const BoxConstraints.tightForFinite());
    renderer.pumpCompleteFrame();

    renderer.onErrors = null;
    expect(caughtErrors!.isNotEmpty, isTrue);
  });

  test('RenderObject.dispose null the layer on repaint boundaries', () {
    final TestRenderObject renderObject = TestRenderObject(allowPaintBounds: true);
    // Force a layer to get set.
    renderObject.isRepaintBoundary = true;
    PaintingContext.repaintCompositedChild(renderObject, debugAlsoPaintedParent: true);
    expect(renderObject.debugLayer, isA<OffsetLayer>());

    // Dispose with repaint boundary still being true.
    renderObject.dispose();
    expect(renderObject.debugLayer, null);
  });

  test('RenderObject.dispose nulls the layer on non-repaint boundaries', () {
    final TestRenderObject renderObject = TestRenderObject(allowPaintBounds: true);
    // Force a layer to get set.
    renderObject.isRepaintBoundary = true;
    PaintingContext.repaintCompositedChild(renderObject, debugAlsoPaintedParent: true);

    // Dispose with repaint boundary being false.
    renderObject.isRepaintBoundary = false;
    renderObject.dispose();
    expect(renderObject.debugLayer, null);
  });
}

// Tests the create-update cycle by pumping two frames. The first frame has no
// prior layer and forces the painting context to create a new one. The second
// frame reuses the layer painted on the first frame.
void _testPaintingContextLayerReuse<L extends Layer>(_LayerTestPaintCallback painter) {
  final _TestCustomLayerBox box = _TestCustomLayerBox(painter);
  layout(box, phase: EnginePhase.paint);

  // Force a repaint. Otherwise, pumpFrame is a noop.
  box.markNeedsPaint();
  pumpFrame(phase: EnginePhase.paint);
  expect(box.paintedLayers, hasLength(2));
  expect(box.paintedLayers[0], isA<L>());
  expect(box.paintedLayers[0], same(box.paintedLayers[1]));
}

typedef _LayerTestPaintCallback = Layer? Function(PaintingContextCallback painter, PaintingContext context, Offset offset, Layer? oldLayer);

class _TestCustomLayerBox extends RenderBox {
  _TestCustomLayerBox(this.painter);

  final _LayerTestPaintCallback painter;
  final List<Layer> paintedLayers = <Layer>[];

  @override
  bool get isRepaintBoundary => false;

  @override
  void performLayout() {
    size = constraints.smallest;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final Layer paintedLayer = painter(super.paint, context, offset, layer)!;
    paintedLayers.add(paintedLayer);
    layer = paintedLayer as ContainerLayer;
  }
}

class TestParentData extends ParentData with ContainerParentDataMixin<RenderBox> { }

class TestRenderObject extends RenderObject {
  TestRenderObject({this.allowPaintBounds = false});

  final bool allowPaintBounds;

  @override
  bool isRepaintBoundary = false;

  @override
  void debugAssertDoesMeetConstraints() { }

  @override
  Rect get paintBounds {
    assert(allowPaintBounds); // For some tests, this should not get called.
    return Rect.zero;
  }

  @override
  void performLayout() { }

  @override
  void performResize() { }

  @override
  Rect get semanticBounds => const Rect.fromLTWH(0.0, 0.0, 10.0, 20.0);

  int describeSemanticsConfigurationCallCount = 0;

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    config.isSemanticBoundary = true;
    describeSemanticsConfigurationCallCount++;
  }
}

class LeaderLayerRenderObject extends RenderObject {
  LeaderLayerRenderObject();

  LayerLink? layerLink;

  @override
  bool isRepaintBoundary = true;

  @override
  void debugAssertDoesMeetConstraints() { }

  @override
  Rect get paintBounds {
    return Rect.zero;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (layerLink != null) {
      context.pushLayer(LeaderLayer(link: layerLink!), super.paint, offset);
    }
  }

  @override
  void performLayout() { }

  @override
  void performResize() { }

  @override
  Rect get semanticBounds => const Rect.fromLTWH(0.0, 0.0, 10.0, 20.0);
}

class TestThrowingRenderObject extends RenderObject {
  @override
  void performLayout() {
    throw FlutterError('TestThrowingRenderObject does not support performLayout.');
  }

  @override
  void debugAssertDoesMeetConstraints() { }

  @override
  Rect get paintBounds {
    assert(false); // The test shouldn't call this.
    return Rect.zero;
  }

  @override
  void performResize() { }

  @override
  Rect get semanticBounds {
    assert(false); // The test shouldn't call this.
    return Rect.zero;
  }
}
