///
/// [Author] Alex (https://github.com/AlexVincent525)
/// [Date] 2020/3/31 16:27
///
import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:extended_image/extended_image.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:provider/provider.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';

import '../constants/constants.dart';
import '../widget/builder/image_page_builder.dart';
import '../widget/builder/video_page_builder.dart';
import '../widget/fade_image_builder.dart';
import '../widget/platform_progress_indicator.dart';
import '../widget/rounded_check_box.dart';

class AssetPickerViewer extends StatefulWidget {
  const AssetPickerViewer({
    Key key,
    @required this.currentIndex,
    @required this.assets,
    @required this.themeData,
    this.selectedAssets,
    this.selectorProvider,
    this.textDelegate,
  }) : super(key: key);

  /// Current previewing index in assets.
  /// 当前查看的索引
  final int currentIndex;

  /// Assets provided to preview.
  /// 提供预览的资源
  final Set<AssetEntity> assets;

  /// Selected assets.
  /// 已选的资源
  final Set<AssetEntity> selectedAssets;

  /// Provider for [AssetPicker].
  /// 资源选择器的状态保持
  final AssetPickerProvider selectorProvider;

  /// Theme for viewer.
  /// 主题
  final ThemeData themeData;

  /// [TextDelegate] that the viewer would use.
  /// 预览部件会使用的文本构建
  final TextDelegate textDelegate;

  @override
  AssetPickerViewerState createState() => AssetPickerViewerState();

  /// Static method to push with navigator.
  /// 跳转至选择预览的静态方法
  static Future<Set<AssetEntity>> pushToViewer(
    BuildContext context, {
    int currentIndex = 0,
    @required Set<AssetEntity> assets,
    @required ThemeData themeData,
    Set<AssetEntity> selectedAssets,
    AssetPickerProvider selectorProvider,
    TextDelegate textDelegate,
  }) async {
    final WidgetBuilder viewer = (BuildContext _) => AssetPickerViewer(
          currentIndex: currentIndex,
          assets: assets,
          themeData: themeData,
          selectedAssets: selectedAssets,
          selectorProvider: selectorProvider,
          textDelegate: textDelegate,
        );
    final Set<AssetEntity> result =
        await Navigator.of(context).push<Set<AssetEntity>>(
      Platform.isAndroid
          ? MaterialPageRoute<Set<AssetEntity>>(builder: viewer)
          : CupertinoPageRoute<Set<AssetEntity>>(builder: viewer),
    );
    return result;
  }
}

class AssetPickerViewerState extends State<AssetPickerViewer>
    with TickerProviderStateMixin {
  /// [StreamController] for viewing page index update.
  /// 用于更新当前正在浏览的资源页码的流控制器
  ///
  /// The main purpose is to narrow down build parts when page index is changing, prevent
  /// widely [setState] and causing other widgets rebuild.
  /// 使用 [StreamController] 的主要目的是缩小页码变化时构建组件的范围，
  /// 防止滥用 [setState] 导致其他部件重新构建。
  final StreamController<int> pageStreamController =
      StreamController<int>.broadcast();

  /// [AnimationController] for double tap animation.
  /// 双击缩放的动画控制器
  AnimationController _doubleTapAnimationController;

  /// [CurvedAnimation] for double tap.
  /// 双击缩放的动画曲线
  Animation<double> _doubleTapCurveAnimation;

  /// [Animation] for double tap.
  /// 双击缩放的动画
  Animation<double> _doubleTapAnimation;

  /// Callback for double tap.
  /// 双击缩放的回调
  VoidCallback _doubleTapListener;

  /// [ChangeNotifier] for photo selector viewer.
  /// 资源预览器的状态保持
  AssetPickerViewerProvider provider;

  /// [PageController] for assets preview [PageView].
  /// 查看图片资源的页面控制器
  PageController pageController;

  /// Current previewing index.
  /// 当前正在预览的资源索引
  int currentIndex;

  /// Whether detail widgets is displayed.
  /// 详情部件是否显示
  bool isDisplayingDetail = true;

  /// Whether the [PageView] can switch between pages. Provide for video play.
  /// 是否允许[PageView]切换页面，用于播放视频时设置。
  bool isAllowSwitchPage = true;

  /// Getter for current asset.
  /// 当前资源的Getter
  AssetEntity get currentAsset => widget.assets.elementAt(currentIndex);

  /// Height for bottom detail widget.
  /// 底部详情部件的高度
  double get bottomDetailHeight => 140.0;

  @override
  void initState() {
    super.initState();

    /// Hide system status bar automatically on iOS.
    /// 在iOS设备上自动隐藏状态栏
    if (Platform.isIOS) {
      SystemChrome.setEnabledSystemUIOverlays(<SystemUiOverlay>[]);
    }
    _doubleTapAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _doubleTapCurveAnimation = CurvedAnimation(
      parent: _doubleTapAnimationController,
      curve: Curves.easeInOut,
    );
    currentIndex = widget.currentIndex;
    pageController = PageController(initialPage: currentIndex);
    if (widget.selectedAssets != null) {
      provider = AssetPickerViewerProvider(widget.selectedAssets);
    }
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIOverlays(SystemUiOverlay.values);
    _doubleTapAnimationController?.dispose();
    pageStreamController?.close();
    super.dispose();
  }

  /// Execute scale animation when double tap.
  /// 双击时执行缩放动画
  void updateAnimation(ExtendedImageGestureState state) {
    final double begin = state.gestureDetails.totalScale;
    final double end = state.gestureDetails.totalScale == 1.0 ? 3.0 : 1.0;
    final Offset pointerDownPosition = state.pointerDownPosition;

    _doubleTapAnimation?.removeListener(_doubleTapListener);
    _doubleTapAnimationController
      ..stop()
      ..reset();
    _doubleTapListener = () {
      state.handleDoubleTap(
        scale: _doubleTapAnimation.value,
        doubleTapPosition: pointerDownPosition,
      );
    };
    _doubleTapAnimation = Tween<double>(
      begin: begin,
      end: end,
    ).animate(_doubleTapCurveAnimation)
      ..addListener(_doubleTapListener);

    _doubleTapAnimationController.forward();
  }

  /// Method to switch [isDisplayingDetail].
  /// 切换显示详情状态的方法
  void switchDisplayingDetail() {
    isDisplayingDetail = !isDisplayingDetail;
    if (!Platform.isIOS) {
      SystemChrome.setEnabledSystemUIOverlays(
        isDisplayingDetail ? SystemUiOverlay.values : <SystemUiOverlay>[],
      );
    }
    if (mounted) {
      setState(() {});
    }
  }

  /// Methods to set [isAllowSwitchPage].
  /// 设置是否允许切换页面的方法
  void allowSwitchPages(bool value) {
    if (value == isAllowSwitchPage) {
      return;
    }
    isAllowSwitchPage = value;
    if (mounted) {
      setState(() {});
    }
  }

  /// Split page builder according to type of asset.
  /// 根据资源类型使用不同的构建页
  Widget assetPageBuilder(BuildContext context, int index) {
    final AssetEntity asset = widget.assets.elementAt(index);
    Widget builder;
    switch (asset.type) {
      case AssetType.audio:
//        builder = audioPageBuilder(context, index);
        builder = const SizedBox.shrink();
        break;
      case AssetType.image:
        builder = ImagePageBuilder(asset: asset, state: this);
        break;
      case AssetType.video:
        builder = VideoPageBuilder(asset: asset, state: this);
        break;
      case AssetType.other:
        builder = Center(child: Text(widget.textDelegate.unSupportedAssetType));
        break;
    }
    return builder;
  }

  /// Common image load state changed callback with [Widget].
  /// 图片加载状态的部件回调
  Widget previewWidgetLoadStateChanged(ExtendedImageState state) {
    Widget loader;
    switch (state.extendedImageLoadState) {
      case LoadState.loading:
        loader = Center(
          child: PlatformProgressIndicator(
            color: widget.themeData.buttonColor,
            size: Screens.width / 10,
          ),
        );
        break;
      case LoadState.completed:
        loader = FadeImageBuilder(child: state.completedWidget);
        break;
      case LoadState.failed:
        loader = _failedItem;
        break;
    }
    return loader;
  }

  /// AppBar widget.
  /// 顶栏部件
  Widget appBar(BuildContext context) => AnimatedPositioned(
        duration: kThemeAnimationDuration,
        curve: Curves.easeInOut,
        top: isDisplayingDetail
            ? 0.0
            : -(Screens.topSafeHeight + kToolbarHeight),
        left: 0.0,
        right: 0.0,
        height: Screens.topSafeHeight + kToolbarHeight,
        child: Container(
          padding: EdgeInsets.only(top: Screens.topSafeHeight, right: 12.0),
          color: Colors.grey[850].withOpacity(0.95),
          child: Row(
            children: <Widget>[
              const BackButton(),
              StreamBuilder<int>(
                initialData: currentIndex,
                stream: pageStreamController.stream,
                builder: (BuildContext _, AsyncSnapshot<int> snapshot) {
                  return Text(
                    '${snapshot.data + 1}/${widget.assets.length}',
                    style: TextStyle(
                      color: Colors.grey[200],
                      fontSize: 18.0,
                      fontWeight: FontWeight.bold,
                    ),
                  );
                },
              ),
              const Spacer(),
              if (provider != null)
                ChangeNotifierProvider<AssetPickerViewerProvider>.value(
                  value: provider,
                  child: confirmButton(context),
                ),
            ],
          ),
        ),
      );

  /// Confirm button.
  /// 确认按钮
  ///
  /// It'll pop with [AssetPickerProvider.selectedAssets] when there're any assets were chosen.
  /// The [PhotoSelector] will recognize and pop too.
  /// 当有资源已选时，点击按钮将把已选资源通过路由返回。
  /// 资源选择器将识别并一同返回。
  Widget confirmButton(BuildContext context) =>
      Consumer<AssetPickerViewerProvider>(
        builder:
            (BuildContext _, AssetPickerViewerProvider provider, Widget __) {
          return MaterialButton(
            minWidth: provider.isSelectedNotEmpty ? 48.0 : 20.0,
            height: 32.0,
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            color: provider.isSelectedNotEmpty
                ? widget.themeData.buttonColor
                : widget.themeData.dividerColor,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(3.0)),
            child: Text(
              provider.isSelectedNotEmpty
                  ? '${widget.textDelegate.confirm}(${provider.currentlySelectedAssets.length}'
                      '/'
                      '${widget.selectorProvider.maxAssets})'
                  : widget.textDelegate.confirm,
              style: TextStyle(
                color: provider.isSelectedNotEmpty
                    ? Colors.white
                    : Colors.grey[600],
                fontSize: 17.0,
                fontWeight: FontWeight.normal,
              ),
            ),
            onPressed: () {
              if (provider.isSelectedNotEmpty) {
                Navigator.of(context).pop(provider.currentlySelectedAssets);
              }
            },
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          );
        },
      );

  /// Thumb item widget in bottom detail.
  /// 底部信息栏单个资源缩略部件
  Widget _bottomDetailItem(int index) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 16.0),
      child: AspectRatio(
        aspectRatio: 1.0,
        child: StreamBuilder<int>(
          initialData: currentIndex,
          stream: pageStreamController.stream,
          builder: (BuildContext _, AsyncSnapshot<int> snapshot) {
            final AssetEntity asset = widget.selectedAssets.elementAt(index);
            final bool isViewing = asset == currentAsset;
            return GestureDetector(
              onTap: () {
                if (widget.assets == widget.selectedAssets) {
                  pageController.jumpToPage(index);
                }
              },
              child: Selector<AssetPickerViewerProvider, Set<AssetEntity>>(
                selector:
                    (BuildContext _, AssetPickerViewerProvider provider) =>
                        provider.currentlySelectedAssets,
                builder: (BuildContext _,
                    Set<AssetEntity> currentlySelectedAssets, Widget __) {
                  final bool isSelected =
                      currentlySelectedAssets.contains(asset);
                  return Stack(
                    children: <Widget>[
                      Positioned.fill(
                        child: RepaintBoundary(
                          child: ExtendedImage(
                            image: AssetEntityImageProvider(
                              widget.assets.elementAt(index),
                              isOriginal: false,
                            ),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      AnimatedContainer(
                        duration: kThemeAnimationDuration,
                        curve: Curves.easeInOut,
                        decoration: BoxDecoration(
                          border: isViewing
                              ? Border.all(
                                  color: widget.themeData.buttonColor,
                                  width: 2.0)
                              : null,
                          color: isSelected ? null : Colors.white54,
                        ),
                      ),
                    ],
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  /// Edit button. (No usage currently)
  /// 编辑按钮 (目前没有使用)
  Widget get editButton => Text(
        widget.textDelegate.edit,
        style: const TextStyle(fontSize: 18.0),
      );

  /// Select button.
  /// 选择按钮
  Widget get selectButton => Row(
        children: <Widget>[
          StreamBuilder<int>(
            initialData: currentIndex,
            stream: pageStreamController.stream,
            builder: (BuildContext _, AsyncSnapshot<int> snapshot) {
              return Selector<AssetPickerViewerProvider, Set<AssetEntity>>(
                selector:
                    (BuildContext _, AssetPickerViewerProvider provider) =>
                        provider.currentlySelectedAssets,
                builder: (BuildContext _,
                    Set<AssetEntity> currentlySelectedAssets, Widget __) {
                  final AssetEntity asset =
                      widget.assets.elementAt(snapshot.data);
                  final bool selected = currentlySelectedAssets.contains(asset);
                  return RoundedCheckbox(
                    value: selected,
                    onChanged: (bool value) {
                      if (selected) {
                        provider.unSelectAssetEntity(asset);
                      } else {
                        provider.selectAssetEntity(asset);
                      }
                    },
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  );
                },
              );
            },
          ),
          Text(widget.textDelegate.select,
              style: const TextStyle(fontSize: 18.0)),
        ],
      );

  /// Detail widget aligned to bottom.
  /// 底部信息部件
  Widget get bottomDetail => AnimatedPositioned(
        duration: kThemeAnimationDuration,
        curve: Curves.easeInOut,
        bottom: isDisplayingDetail
            ? 0.0
            : -(Screens.bottomSafeHeight + bottomDetailHeight),
        left: 0.0,
        right: 0.0,
        height: Screens.bottomSafeHeight + bottomDetailHeight,
        child: ChangeNotifierProvider<AssetPickerViewerProvider>.value(
          value: provider,
          child: Container(
            padding: EdgeInsets.only(bottom: Screens.bottomSafeHeight),
            color: Colors.grey[850].withOpacity(0.95),
            child: Column(
              children: <Widget>[
                SizedBox(
                  height: 90.0,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.zero,
                    itemCount: widget.selectedAssets.length,
                    itemBuilder: (BuildContext _, int index) =>
                        _bottomDetailItem(index),
                  ),
                ),
                Container(
                  height: 1.0,
                  color: widget.themeData.dividerColor,
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        const Spacer(),
                        selectButton,
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  /// Item widget when [AssetEntity.thumbData] load failed.
  /// 资源缩略数据加载失败时使用的部件
  Widget get _failedItem => Center(
        child: Text(
          widget.textDelegate.loadFailed,
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white, fontSize: 18.0),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: widget.themeData,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Material(
          color: Colors.black,
          child: Stack(
            children: <Widget>[
              Positioned.fill(
                child: PageView.builder(
                  physics: isAllowSwitchPage
                      ? const CustomScrollPhysics()
                      : const NeverScrollableScrollPhysics(),
                  controller: pageController,
                  itemCount: widget.assets.length,
                  itemBuilder: assetPageBuilder,
                  onPageChanged: (int index) {
                    currentIndex = index;
                    pageStreamController.add(index);
                  },
                  scrollDirection: Axis.horizontal,
                ),
              ),
              appBar(context),
              if (widget.selectedAssets != null) bottomDetail,
            ],
          ),
        ),
      ),
    );
  }
}
