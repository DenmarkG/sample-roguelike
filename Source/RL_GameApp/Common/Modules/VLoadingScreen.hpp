/*
 *
 * Confidential Information of Telekinesys Research Limited (t/a Havok). Not for disclosure or distribution without Havok's
 * prior written consent. This software contains code, techniques and know-how which is confidential and proprietary to Havok.
 * Product and Trade Secret source code contains trade secrets of Havok. Havok Software (C) Copyright 1999-2013 Telekinesys Research Limited t/a Havok. All Rights Reserved. Use of this software is subject to the terms of an end user license agreement.
 *
 */

#ifndef __V_LOADING_SCREEN
#define __V_LOADING_SCREEN

#include <Vision/Runtime/Engine/System/Vision.hpp>
#include <Vision/Runtime/Framework/VisionApp/VAppModule.hpp>
#include <Vision/Runtime/Engine/System/Timer/VisApiPerformanceTimer.hpp>

/// \brief
///   Simple Loading Screen which shows a progress bar and optionally an image.
///
/// \ingroup VisionAppFramework
class VLoadingScreenBase : public VAppModule
{
  V_DECLARE_DYNCREATE(VLoadingScreenBase);

public:
  /// \brief
  ///   Specifies if and how the aspect ratio of the background texture is maintained.
  enum AspectRatioAlignment
  {
    ALIGN_NONE = 0,     ///< Fullscreen display of the background texture.
    ALIGN_HORIZONTAL,   ///< Keep the texture's aspect ratio and align it horizontally (i.e., pad or cut off the top and bottom part of the texture, if necessary).
    ALIGN_VERTICAL,     ///< Keep the texture's aspect ratio and align it vertically (i.e., pad of cut off the left and right borders of the texture, if necessary).
    ALIGN_FULL,         ///< Keep the texture's aspect ratio and fit the whole texture on screen.
  };

  /// \brief
  ///   Specifies additional loading screen options.
  enum LoadingScreenFlags
  {
    LSF_SHOW_PROGRESSBAR      = V_BIT(1), ///< Show progress bar.
    LSF_SHOW_BACKGROUNDIMAGE  = V_BIT(2), ///< Show loading background image.
    LSF_FADEOUT_SMOOTH        = V_BIT(3), ///< Use sinusoidal (instead of linear) function for fadeout of loading screen when loading has finished.

    LSF_DEFAULT = (LSF_SHOW_PROGRESSBAR | LSF_SHOW_BACKGROUNDIMAGE | LSF_FADEOUT_SMOOTH)
  };

  /// \brief
  ///   Structure for specifying the loading screen settings.
  struct Settings
  {
    Settings(const char* szImagePath = "");

    VString m_sImagePath;                         ///< Path to the background image to be displayed on the loading screen. 
    VColorRef m_backgroundColor;                  ///< Color used to clear the background.
    VColorRef m_progressBarColor;                 ///< The color of the progress bar.
    VColorRef m_progressBarBackgroundColor;       ///< Background color for the progress bar rectangle.
    AspectRatioAlignment m_eAspectRatioAlignment; ///< Alignment specification for the loading image.
    float m_fFadeOutTime;                         ///< Time for the loading screen to fade out after loading has finished.
    VRectanglef m_progressBarRect;                ///< Specifies the extents of the progress bar using pixel coordinates in the loading image. Default is invalid.
    unsigned int m_uiFlags;                       ///< Additional flags of type LoadingScreenFlags.
  };

  virtual void Init() HKV_OVERRIDE;
  virtual void DeInit() HKV_OVERRIDE;

  void SetSettings(const Settings& settings);
  inline const Settings& GetSettings() const { return m_settings; }

  virtual void OnHandleCallback(IVisCallbackDataObject_cl* pData) HKV_OVERRIDE;

protected:
  /// \brief
  ///   Objects of VLoadingScreenBase can not be instantiated, use VLoadingScreen instead.
  VLoadingScreenBase(const Settings& settings = Settings());
  virtual ~VLoadingScreenBase() {}

  virtual void LoadingStarted();
  virtual void LoadingFinished();
  virtual void LoadingInProgress(float fPercentage);

  const VisPerformanceTimer_cl& GetTimer() const { return m_timer; }

  /// \brief
  ///   Override to use custom background image loading.
  virtual VTextureObject* CreateBackgroundImage();

  virtual const VRectanglef GetLoadingScreenExtents() const;
  virtual const VRectanglef GetBackgroundImageExtents() const;
  virtual const VRectanglef GetProgressBarExtents() const;

  virtual void OnDraw() const;

  /// \brief
  ///   Draws a rectangle with the loading screen's fade out applied.
  void DrawRectFaded(IVRender2DInterface* pRenderInterface, const VColorRef& color, const VRectanglef& rect) const;
  void DrawRectFaded(IVRender2DInterface* pRenderInterface, VTextureObject* pTexture, const VColorRef& ref, const VRectanglef& rect) const;

private:
  void UpdateLayout();
  void CleanUpLoadingScreen();

  Settings m_settings;
  VTextureObjectPtr m_spBackgroundTexture;

  enum LoadingScreenState
  {
    STATE_DISABLED,
    STATE_LOADING,
    STATE_AFTER_LOADING,
    STATE_FADING_OUT
  };

  LoadingScreenState m_eState;
  float m_fCurrentProgress;
  VisPerformanceTimer_cl m_timer;
  float m_fCurrentFadeOutTime;

  // Layout Rectangles
  VRectanglef m_backgroundImageRect;
  VRectanglef m_progressBarBackgroundRect;
  VRectanglef m_progressBarRect;
};

/// \brief
///   Loading screen implementation for scene loading.
///
/// \ingroup VisionAppFramework
class VLoadingScreen : public VLoadingScreenBase
{
  V_DECLARE_DYNCREATE(VLoadingScreen);

public:
  VLoadingScreen(const Settings& settings = Settings())
    : VLoadingScreenBase(settings)
  {}

  virtual void OnHandleCallback(IVisCallbackDataObject_cl* pData) HKV_OVERRIDE
  {
    if (pData->m_pSender == &Vision::Callbacks.OnProgress)
    {
      // Only react to the message if it is of type PDOT_LOADING_SCENE.
      VisProgressDataObject_cl* pPDO = (VisProgressDataObject_cl*)pData;
      if (pPDO->m_eType != VisProgressDataObject_cl::PDOT_LOADING_SCENE)
        return;
    }

    VLoadingScreenBase::OnHandleCallback(pData);
  }
};

#endif //__V_LOADING_SCREEN

/*
 * Havok SDK - Base file, BUILD(#20131218)
 * 
 * Confidential Information of Havok.  (C) Copyright 1999-2013
 * Telekinesys Research Limited t/a Havok. All Rights Reserved. The Havok
 * Logo, and the Havok buzzsaw logo are trademarks of Havok.  Title, ownership
 * rights, and intellectual property rights in the Havok software remain in
 * Havok and/or its suppliers.
 * 
 * Use of this software for evaluation purposes is subject to and indicates
 * acceptance of the End User licence Agreement for this product. A copy of
 * the license is included with this software and is also available from salesteam@havok.com.
 * 
 */
