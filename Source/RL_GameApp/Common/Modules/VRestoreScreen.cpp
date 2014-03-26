/*
 *
 * Confidential Information of Telekinesys Research Limited (t/a Havok). Not for disclosure or distribution without Havok's
 * prior written consent. This software contains code, techniques and know-how which is confidential and proprietary to Havok.
 * Product and Trade Secret source code contains trade secrets of Havok. Havok Software (C) Copyright 1999-2013 Telekinesys Research Limited t/a Havok. All Rights Reserved. Use of this software is subject to the terms of an end user license agreement.
 *
 */

#include <Vision/Runtime/Framework/VisionApp/Modules/VRestoreScreen.hpp>
#include <Vision/Runtime/Framework/VisionApp/VAppBase.hpp>
#include <Vision/Runtime/Framework/VisionApp/VAppImpl.hpp>

V_IMPLEMENT_DYNCREATE(VRestoreScreen, VLoadingScreenBase, Vision::GetEngineModule());

VRestoreScreen::VRestoreScreen()
  : VLoadingScreenBase(Settings())
  , m_bGrab(false)
  , m_pScreenshotBuffer(NULL)
  , m_fBrightness(0.7f)
  , m_fSaturation(0.2f)
{
}

VRestoreScreen::VRestoreScreen(float fBrightness, float fSaturation)
  : VLoadingScreenBase(Settings())
  , m_bGrab(false)
  , m_pScreenshotBuffer(NULL)
  , m_fBrightness(fBrightness)
  , m_fSaturation(fSaturation)
{
}

void VRestoreScreen::Init()
{
  VLoadingScreenBase::Init();

  Vision::Callbacks.OnBeforeSwapBuffers += this;
  Vision::Callbacks.OnLeaveForeground += this;
  Vision::Callbacks.OnEnterForeground += this;
  Vision::Callbacks.OnEnterBackground += this;
}

void VRestoreScreen::DeInit()
{
  Vision::Callbacks.OnBeforeSwapBuffers -= this;
  Vision::Callbacks.OnLeaveForeground -= this;
  Vision::Callbacks.OnEnterForeground -= this;
  Vision::Callbacks.OnEnterBackground -= this;

  V_SAFE_DELETE_ARRAY(m_pScreenshotBuffer);

  VLoadingScreenBase::DeInit();
}

void VRestoreScreen::OnHandleCallback(IVisCallbackDataObject_cl* pData)
{
  if (pData->m_pSender == &Vision::Callbacks.OnProgress)
  {
    // Only react to the message if it signals a background restore.
    VisProgressDataObject_cl* pPDO = (VisProgressDataObject_cl*)pData;
    if (pPDO->m_eType != VisProgressDataObject_cl::PDOT_BACKGROUND_RESTORE)
      return;
  }
  else if (pData->m_pSender == &Vision::Callbacks.OnBeforeSwapBuffers)
  {
    if (m_bGrab)
    {
      GrabBackgroundScreenshot();
      m_bGrab = false;
    }
  }
  else if (pData->m_pSender == &Vision::Callbacks.OnLeaveForeground)
  {
    // Only grab a screen shot if the application is currently running.
    if (VAppBase::Get()->GetAppState() == VAppHelper::AS_RUNNING)
    {
      m_bGrab = true;
    }
    else
    {
      // Otherwise copy loading screen settings from VLoadingScreen module (if present).
      VLoadingScreen* pLoadingScreenModule = GetParent()->GetAppModule<VLoadingScreen>();
      if (pLoadingScreenModule != NULL)
      {
        // But disable the fade out.
        Settings settings = pLoadingScreenModule->GetSettings();
        settings.m_fFadeOutTime = 0.0f;
        SetSettings(settings);
      }
    }
  }
  else if (pData->m_pSender == &Vision::Callbacks.OnEnterBackground)
  {
    // Save the screen shot only now to reduce the time spent in Vision::Callbacks.OnLeaveForeground.
    // This is critical on Android devices.
    SaveBackgroundScreenshot();
  }
  else if (pData->m_pSender == &Vision::Callbacks.OnEnterForeground)
  {
    // Reset screen shot grab state in case the application only went to the sleep state on Android.
    m_bGrab = false;
    V_SAFE_DELETE_ARRAY(m_pScreenshotBuffer);
  }

  VLoadingScreenBase::OnHandleCallback(pData);
}

VTextureObject* VRestoreScreen::CreateBackgroundImage()
{
  // Auto mip map generation not supported on some devices for RGB8.
  VTextureObject* pTexture = Vision::TextureManager.Load2DTexture(GetSettings().m_sImagePath, VTM_FLAG_NO_MIPMAPS);
  if (pTexture != NULL)
  {
    pTexture->SetResourceFlag(VRESOURCEFLAG_AUTODELETE);
  }

  return pTexture;
}

void VRestoreScreen::GrabBackgroundScreenshot()
{
  const int iScreenWidth = Vision::Video.GetXRes();
  const int iScreenHeight = Vision::Video.GetYRes();

  // Write the frame buffer to memory buffer.
  V_SAFE_DELETE_ARRAY(m_pScreenshotBuffer);
  m_pScreenshotBuffer = new unsigned char[iScreenWidth*iScreenHeight*3];
  if (!Vision::Game.WriteScreenToBuffer(0, 0, iScreenWidth, iScreenHeight, static_cast<UBYTE*>(m_pScreenshotBuffer)))
  {
    V_SAFE_DELETE_ARRAY(m_pScreenshotBuffer);
  }
}

void VRestoreScreen::SaveBackgroundScreenshot()
{
  // GrabBackgroundScreenshot() needs to be called before
  if (m_pScreenshotBuffer == NULL)
    return;

  const int iScreenWidth = Vision::Video.GetXRes();
  const int iScreenHeight = Vision::Video.GetYRes();
  ColorCorrect(m_pScreenshotBuffer, iScreenWidth, iScreenHeight, m_fBrightness, m_fSaturation);

  // use VTEX to scale and save the image
  Image_cl image;
  ImageMap_cl colorMap(iScreenWidth, iScreenHeight, 24, static_cast<UBYTE*>(m_pScreenshotBuffer));
  image.AddColorMap(colorMap);

  // Decide which resolution to use for the saved image.
  int iScaledWidth = 512;
  while (iScaledWidth > iScreenWidth || iScaledWidth > iScreenHeight)
  {
    iScaledWidth /= 2;
    VASSERT(iScaledWidth > 0);
  }

  image.Scale(iScaledWidth, iScaledWidth);

  const char* szFilename = ":app_cache/vision_background.bmp";
  IVFileOutStream* pOut = Vision::File.Create(szFilename);
  const bool bSaved = (image.SaveBMP(pOut) == VERR_NOERROR);
  V_SAFE_DELETE_ARRAY(m_pScreenshotBuffer);

  if (pOut != NULL)
    pOut->Close();

  if (bSaved)
  {
    // Set up loading screen settings.
    Settings settings(szFilename);
    settings.m_eAspectRatioAlignment = ALIGN_NONE;
    SetSettings(settings);
  }
  else
  {
    hkvLog::Dev("VRestoreScreen: Could not save backgrounding screenshot\n");
  }
}

void VRestoreScreen::ColorCorrect(unsigned char* pBuffer, int iWidth, int iHeight, float fBrightness, float fSaturation)
{
  float fLumFactors[3] = { 0.114f * fBrightness, 0.587f * fBrightness, 0.299f * fBrightness };
  const float fInvSaturation = 1.0f - fSaturation;

  for (int y = 0; y < iHeight; ++y)
  {
    unsigned char *pRow = &pBuffer[y*iWidth*3];
    for (int x = 0; x < iWidth; ++x, pRow += 3)
    {
      unsigned char tmp[3] = { pRow[0], pRow[1], pRow[2] };

      const float fLum = 
        static_cast<float>(pRow[0]) * fLumFactors[0] +
        static_cast<float>(pRow[1]) * fLumFactors[1] +
        static_cast<float>(pRow[2]) * fLumFactors[2];

      float fInvSaturationProduct = fInvSaturation * fLum;
      pRow[0] = hkvMath::Min(255, static_cast<unsigned char>(
        fSaturation * static_cast<float>(tmp[0]) + fInvSaturationProduct));
      pRow[1] = hkvMath::Min(255, static_cast<unsigned char>(
        fSaturation * static_cast<float>(tmp[1]) + fInvSaturationProduct));
      pRow[2] = hkvMath::Min(255, static_cast<unsigned char>(
        fSaturation * static_cast<float>(tmp[2]) + fInvSaturationProduct));
    }
  }
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
