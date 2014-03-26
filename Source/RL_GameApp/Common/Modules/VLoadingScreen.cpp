/*
 *
 * Confidential Information of Telekinesys Research Limited (t/a Havok). Not for disclosure or distribution without Havok's
 * prior written consent. This software contains code, techniques and know-how which is confidential and proprietary to Havok.
 * Product and Trade Secret source code contains trade secrets of Havok. Havok Software (C) Copyright 1999-2013 Telekinesys Research Limited t/a Havok. All Rights Reserved. Use of this software is subject to the terms of an end user license agreement.
 *
 */

#include <Vision/Runtime/Framework/VisionApp/Modules/VLoadingScreen.hpp>
#include <Vision/Runtime/Framework/VisionApp/VAppImpl.hpp>

// VLoadingScreen settings.
VLoadingScreenBase::Settings::Settings(const char* szImagePath)
  : m_sImagePath(szImagePath)
  , m_backgroundColor(V_RGBA_BLACK)
  , m_progressBarColor(VAppMenuColors::GetColor(VAppMenuColors::COLOR_LIST_ITEM_TEXT_SELECTED))
  , m_progressBarBackgroundColor(VAppMenuColors::GetColor(VAppMenuColors::COLOR_DIALOG_BG))
  , m_eAspectRatioAlignment(ALIGN_HORIZONTAL)
  , m_fFadeOutTime(0.5f)
  , m_progressBarRect()
  , m_uiFlags(LSF_DEFAULT)
{
  if (m_sImagePath.IsEmpty())
  {
#if defined(HK_ANARCHY)

    m_eAspectRatioAlignment = ALIGN_VERTICAL;
    m_sImagePath = "Textures/Anarchy_Splash_1024x512.dds";

#else

    m_eAspectRatioAlignment = ALIGN_HORIZONTAL;
    m_backgroundColor = VColorRef(35, 31, 32);
    m_sImagePath = "Textures/Havok_Logo_1024x512.dds";

#endif
  }
}

// VLoadingScreen(Base)
V_IMPLEMENT_DYNCREATE_ABSTRACT(VLoadingScreenBase, VAppModule, Vision::GetEngineModule());
V_IMPLEMENT_DYNCREATE(VLoadingScreen, VLoadingScreenBase, Vision::GetEngineModule());

VLoadingScreenBase::VLoadingScreenBase(const Settings& settings)
  : VAppModule()
  , m_settings(settings)
  , m_spBackgroundTexture(NULL)
  , m_eState(STATE_DISABLED)
  , m_fCurrentProgress(0.0f)
  , m_timer()
  , m_fCurrentFadeOutTime(0.0f)
  , m_backgroundImageRect()
  , m_progressBarBackgroundRect()
  , m_progressBarRect()
{
}

void VLoadingScreenBase::Init()
{
  Vision::Callbacks.OnProgress += this;
}

void VLoadingScreenBase::DeInit()
{
  Vision::Callbacks.OnProgress -= this;

  // Clean up loading state in case the application is quit while loading.
  CleanUpLoadingScreen();
}

void VLoadingScreenBase::SetSettings(const Settings& settings)
{
  m_settings = settings;
}

void VLoadingScreenBase::OnHandleCallback(IVisCallbackDataObject_cl* pData)
{
  if (pData->m_pSender == &Vision::Callbacks.OnProgress)
  {
    VisProgressDataObject_cl* pPDO = static_cast<VisProgressDataObject_cl*>(pData);

    switch (pPDO->m_iStatusFlags)
    {
    case VIS_API_LOADSCENESTATUS_START:
      LoadingStarted();
      break;

    case VIS_API_LOADSCENESTATUS_PROGRESS:
      LoadingInProgress(pPDO->m_fPercentage);
      break;

    case VIS_API_LOADSCENESTATUS_FINISHED:
      LoadingFinished();
      break;
    }
  }
  else if (pData->m_pSender == &Vision::Callbacks.OnRenderHook)
  {
    VisRenderHookDataObject_cl* pRHDO = static_cast<VisRenderHookDataObject_cl*>(pData);
    if (pRHDO->m_iEntryConst != VRH_AFTER_RENDERING)
      return;

    // Check if we need to start fading out.
    if (m_eState == STATE_AFTER_LOADING && !VVideo::IsSplashScreenActive())
    {
      m_eState = STATE_FADING_OUT;
      m_timer.Reset();
    }

    if (m_eState == STATE_FADING_OUT)
    {
      // Accumulate time and ensure time steps don't get too big.
      m_fCurrentFadeOutTime += hkvMath::Min(0.1f, m_timer.GetDiff());

      // Check if fading out has finished.
      if (m_fCurrentFadeOutTime >= m_settings.m_fFadeOutTime)
      {
        CleanUpLoadingScreen();
        return;
      }
    }

    OnDraw();
  }
  else if (pData->m_pSender == &Vision::Callbacks.OnVideoChanged)
  {
    UpdateLayout();
  }
}

void VLoadingScreenBase::LoadingStarted()
{
  m_eState = STATE_LOADING;
  m_fCurrentProgress = 0.0f;
  m_fCurrentFadeOutTime = 0.0f;
  m_timer.Reset();

  Vision::Callbacks.OnRenderHook += this;
  Vision::Callbacks.OnVideoChanged += this;

  m_spBackgroundTexture = CreateBackgroundImage();

  UpdateLayout();
}

void VLoadingScreenBase::LoadingFinished()
{
  const char* szSceneName = GetParent()->GetSceneLoader().GetLastLoadedSceneFileName();
  hkvLog::Success("Loaded '%s' in %.2fs.", szSceneName, m_timer.GetTime());

  // Do not start to fade out yet.
  // Other initializations steps might still need to be performed
  // after the scene has finished loading.
  m_eState = STATE_AFTER_LOADING;
}

void VLoadingScreenBase::LoadingInProgress(float fPercentage)
{
  m_fCurrentProgress = hkvMath::saturate(fPercentage * 0.01f);
}

VTextureObject* VLoadingScreenBase::CreateBackgroundImage()
{
  VTextureObject* pTexture = NULL;

  // Create texture for background image.
  if ((m_settings.m_uiFlags & LSF_SHOW_BACKGROUNDIMAGE) != 0)
  {
    pTexture = Vision::TextureManager.Load2DTexture(m_settings.m_sImagePath);
    if (pTexture != NULL)
    {
      pTexture->SetResourceFlag(VRESOURCEFLAG_AUTODELETE);
    }
  }

  return pTexture;
}

void VLoadingScreenBase::OnDraw() const
{
  const float fScreenWidth = static_cast<float>(Vision::Video.GetXRes());
  const float fScreenHeight = static_cast<float>(Vision::Video.GetYRes());

  IVRender2DInterface *pRI = Vision::RenderLoopHelper.BeginOverlayRendering();

  if (m_backgroundImageRect.IsValid())
  {
    // Draw loading background image.
    DrawRectFaded(pRI, m_spBackgroundTexture, V_RGBA_WHITE, m_backgroundImageRect);

    // Clear rest of the screen using the background color.
    // We're making sure that no overdraw occurs. Overlapping regions would be visible when fading out.
    if (m_backgroundImageRect.m_vMin.x > 0.0f)
      DrawRectFaded(pRI, m_settings.m_backgroundColor, VRectanglef(0.0f, 0.0f, m_backgroundImageRect.m_vMin.x, fScreenHeight));

    if (m_backgroundImageRect.m_vMax.x < fScreenWidth)
      DrawRectFaded(pRI, m_settings.m_backgroundColor, VRectanglef(m_backgroundImageRect.m_vMax.x, 0.0f, fScreenWidth, fScreenHeight));

    if (m_backgroundImageRect.m_vMin.y > 0.0f)
      DrawRectFaded(pRI, m_settings.m_backgroundColor, VRectanglef(m_backgroundImageRect.m_vMin.x, 0.0f, m_backgroundImageRect.m_vMax.x, m_backgroundImageRect.m_vMin.y));

    if (m_backgroundImageRect.m_vMax.y < fScreenHeight)
      DrawRectFaded(pRI, m_settings.m_backgroundColor, VRectanglef(m_backgroundImageRect.m_vMin.x, m_backgroundImageRect.m_vMax.y, m_backgroundImageRect.m_vMax.x, fScreenHeight));
  }
  else
  {
    DrawRectFaded(pRI, m_settings.m_backgroundColor, VRectanglef(0.0f, 0.0f, fScreenWidth, fScreenHeight));
  }

  // Draw progress bar.
  if ((m_settings.m_uiFlags & LSF_SHOW_PROGRESSBAR) != 0)
  {
    // progress bar background
    DrawRectFaded(pRI, m_settings.m_progressBarBackgroundColor, m_progressBarBackgroundRect);

    // progress bar status
    VRectanglef currentProgressBarRect = m_progressBarRect;
    currentProgressBarRect.m_vMax.x = hkvMath::interpolate(m_progressBarRect.m_vMin.x, m_progressBarRect.m_vMax.x, m_fCurrentProgress);
    DrawRectFaded(pRI, m_settings.m_progressBarColor, currentProgressBarRect);
  }

  Vision::RenderLoopHelper.EndOverlayRendering();
}

void VLoadingScreenBase::DrawRectFaded(IVRender2DInterface* pRenderInterface, const VColorRef& color, const VRectanglef& rect) const
{
  DrawRectFaded(pRenderInterface, NULL, color, rect);
}

void VLoadingScreenBase::DrawRectFaded(IVRender2DInterface* pRenderInterface, VTextureObject* pTexture, const VColorRef& color, const VRectanglef& rect) const
{
  // Modify alpha value when fading out.
  VColorRef finalColor = color;
  if (m_eState == STATE_FADING_OUT)
  {
    float fAlphaFactor = m_fCurrentFadeOutTime / m_settings.m_fFadeOutTime;

    // Sinusoidal falloff
    if ((m_settings.m_uiFlags & LSF_FADEOUT_SMOOTH) != 0)
    {
      fAlphaFactor = hkvMath::cosRad(fAlphaFactor * hkvMath::pi()) * 0.5f + 0.5f;
    }
    else
    {
      fAlphaFactor = 1.0f - fAlphaFactor;
    }

    finalColor.a = static_cast<UBYTE>(static_cast<float>(finalColor.a) * fAlphaFactor);
  }

  const VSimpleRenderState_t renderState(finalColor.a < 255 ? VIS_TRANSP_ALPHA : VIS_TRANSP_NONE, 
    RENDERSTATEFLAG_ALWAYSVISIBLE | RENDERSTATEFLAG_FILTERING | RENDERSTATEFLAG_SAMPLERCLAMPING);

  pRenderInterface->DrawTexturedQuad(rect.m_vMin, rect.m_vMax, pTexture, 
    hkvVec2(0.0f, 0.0f), hkvVec2(1.0f, 1.0f), finalColor, renderState);
}

void VLoadingScreenBase::UpdateLayout()
{
  m_backgroundImageRect = GetBackgroundImageExtents();

  m_progressBarBackgroundRect = GetProgressBarExtents();

  const hkvVec2 vProgressBarBorder = hkvVec2(3.0f, 3.0f) * VAppHelper::GetUIScalingFactor();
  m_progressBarRect = m_progressBarBackgroundRect;
  m_progressBarRect.m_vMin += vProgressBarBorder;
  m_progressBarRect.m_vMax -= vProgressBarBorder;
}

const VRectanglef VLoadingScreenBase::GetLoadingScreenExtents() const
{
  return VRectanglef(0.0f, 0.0f, static_cast<float>(Vision::Video.GetXRes()), static_cast<float>(Vision::Video.GetYRes()));
}

const VRectanglef VLoadingScreenBase::GetBackgroundImageExtents() const
{
  if (m_spBackgroundTexture == NULL)
    return VRectanglef(); // Return invalid rectangle.

  const VRectanglef screenExtents = GetLoadingScreenExtents();

  if (m_settings.m_eAspectRatioAlignment == ALIGN_NONE)
    return screenExtents;

  const float fImageAspectRatio = 
    static_cast<float>(m_spBackgroundTexture->GetTextureWidth()) /
    static_cast<float>(m_spBackgroundTexture->GetTextureHeight());
  const float fScreenAspectRatio = screenExtents.GetSizeX() / screenExtents.GetSizeY();
  const hkvVec2 vScreenCenter = screenExtents.GetCenter();

  if (m_settings.m_eAspectRatioAlignment == ALIGN_HORIZONTAL ||
    (m_settings.m_eAspectRatioAlignment == ALIGN_FULL && fImageAspectRatio > fScreenAspectRatio))
  {
    // Align horizontally.
    const float fHalfHeight = (screenExtents.GetSizeX() / fImageAspectRatio) * 0.5f;
    return VRectanglef(
      screenExtents.m_vMin.x, vScreenCenter.y - fHalfHeight,
      screenExtents.m_vMax.x, vScreenCenter.y + fHalfHeight);
  }
  else
  {
    // Align vertically.
    const float fHalfWidth = (screenExtents.GetSizeY() * fImageAspectRatio) * 0.5f;
    return VRectanglef(
      vScreenCenter.x - fHalfWidth, screenExtents.m_vMin.y,
      vScreenCenter.x + fHalfWidth, screenExtents.m_vMax.y);
  }
}

const VRectanglef VLoadingScreenBase::GetProgressBarExtents() const
{
  if (!m_settings.m_progressBarRect.IsValid() || m_spBackgroundTexture == NULL)
  {
    const VRectanglef loadingScreenRect = GetLoadingScreenExtents();

    // Place progress bar at one quarter of the height.
    float y = (loadingScreenRect.m_vMin.y + 3.0f*loadingScreenRect.m_vMax.y) / 4.0f;

    const float fScale = VAppHelper::GetUIScalingFactor();
    return VRectanglef(loadingScreenRect.m_vMin.x + 100.0f, y,
                       loadingScreenRect.m_vMax.x - 100.0f, y + 20.0f*fScale);
  } 
  else
  {
    const VRectanglef backgroundImgRect = GetBackgroundImageExtents();

    float fTexWidth = static_cast<float>(m_spBackgroundTexture->GetTextureWidth());
    float fTexHeight = static_cast<float>(m_spBackgroundTexture->GetTextureHeight());

    // transform to screen
    float fLeftFrac = static_cast<float>(m_settings.m_progressBarRect.m_vMin.x) / fTexWidth;
    float fTopFrac = static_cast<float>(m_settings.m_progressBarRect.m_vMin.y) / fTexHeight;
    float fRightFrac = static_cast<float>(m_settings.m_progressBarRect.m_vMax.x) / fTexWidth;
    float fBottomFrac = static_cast<float>(m_settings.m_progressBarRect.m_vMax.y) / fTexHeight;

    return VRectanglef(
      hkvMath::floor(backgroundImgRect.m_vMin.x + fLeftFrac*backgroundImgRect.GetSizeX() + 0.5f),
      hkvMath::floor(backgroundImgRect.m_vMin.y + fTopFrac*backgroundImgRect.GetSizeY() + 0.5f),
      hkvMath::floor(backgroundImgRect.m_vMin.x + fRightFrac*backgroundImgRect.GetSizeX() + 0.5f),
      hkvMath::floor(backgroundImgRect.m_vMin.y + fBottomFrac*backgroundImgRect.GetSizeY() + 0.5f));
  }
}

void VLoadingScreenBase::CleanUpLoadingScreen()
{
  if (m_eState == STATE_DISABLED)
    return;

  m_eState = STATE_DISABLED;
  m_spBackgroundTexture = NULL;

  Vision::Callbacks.OnRenderHook -= this;
  Vision::Callbacks.OnVideoChanged -= this;
}

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
