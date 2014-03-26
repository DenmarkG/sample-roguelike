/*
 *
 * Confidential Information of Telekinesys Research Limited (t/a Havok). Not for disclosure or distribution without Havok's
 * prior written consent. This software contains code, techniques and know-how which is confidential and proprietary to Havok.
 * Product and Trade Secret source code contains trade secrets of Havok. Havok Software (C) Copyright 1999-2013 Telekinesys Research Limited t/a Havok. All Rights Reserved. Use of this software is subject to the terms of an end user license agreement.
 *
 */

#include <Vision/Runtime/Framework/VisionApp/Win/VAppWin.hpp>
#include <Vision/Runtime/Framework/VisionApp/VAppImpl.hpp>

#include <Vision/Runtime/Base/System/IO/FileSystems/VFileServeDaemon.hpp>

VAppWin::VAppWin(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPSTR lpCmdLine, int nCmdShow)
  : VAppBase()
  , m_sInitialWorkingDirectory()
{
  char szBuffer[FS_MAX_PATH];

  VFileHelper::GetCurrentWorkingDir(szBuffer, FS_MAX_PATH);
  m_sInitialWorkingDirectory = szBuffer;
}

VAppWin::~VAppWin()
{
  if (!m_sInitialWorkingDirectory.IsEmpty())
    VFileHelper::ChDir(m_sInitialWorkingDirectory.AsChar());
}

void VAppWin::PlatformInit()
{
  VStreamProcessor::Initialize(1);
  VAppBase::PlatformInit();
}

void VAppWin::PlatformInitSettings()
{
  // Check if chosen resolution is actually supported.
  if(m_appConfig.m_videoConfig.m_bFullScreen)
  {	  
    if((m_appConfig.m_videoConfig.m_iXRes == 0) && (m_appConfig.m_videoConfig.m_iYRes == 0))
    {
      DEVMODEA deviceMode;
      deviceMode = Vision::Video.GetAdapterMode(m_appConfig.m_videoConfig.m_iAdapter);

      m_appConfig.m_videoConfig.m_iXRes = deviceMode.dmPelsWidth;
      m_appConfig.m_videoConfig.m_iYRes = deviceMode.dmPelsHeight;
    }

    int newX, newY;
    bool bSupported = CheckFullscreenResolution(m_appConfig.m_videoConfig.m_iAdapter, m_appConfig.m_videoConfig.m_iXRes, m_appConfig.m_videoConfig.m_iYRes, &newX, &newY);
    if (!bSupported)
    {
      hkvLog::Warning( "The selected resolution (%dx%d) isn't supported in fullscreen, using %dx%d instead.", 
        m_appConfig.m_videoConfig.m_iXRes, m_appConfig.m_videoConfig.m_iYRes, newX, newY);
    }

    m_appConfig.m_videoConfig.m_iXRes = newX;
    m_appConfig.m_videoConfig.m_iYRes = newY;
  }

  VASSERT(m_pAppImpl != NULL);
  VAppMenuContextPtr pContext = m_pAppImpl->GetContext();
  pContext->SetKeyboardEnterAsMouseLeftClick(false);

  VAppBase::PlatformInitSettings();
}

void VAppWin::PlatformMapInput()
{
  VInputMap* pInputMap = m_pAppImpl->GetInputMap();

#if defined(SUPPORTS_KEYBOARD)
  // Debug console is always available
  Vision::GetConsoleManager()->SetAllowed(true);

  pInputMap->MapTrigger(VAPP_EXIT, V_KEYBOARD, CT_KB_ESC, VInputOptions::OncePerFrame(ONCE_ON_RELEASE));
  pInputMap->MapTrigger(VAPP_MENU, V_KEYBOARD, CT_KB_F1, VInputOptions::OncePerFrame(ONCE_ON_RELEASE));
  pInputMap->MapTrigger(VAPP_MENU_UP, V_KEYBOARD, CT_KB_UP, VInputOptions::OncePerFrame(ONCE_ON_RELEASE));
  pInputMap->MapTrigger(VAPP_MENU_DOWN, V_KEYBOARD, CT_KB_DOWN, VInputOptions::OncePerFrame(ONCE_ON_RELEASE));
  pInputMap->MapTrigger(VAPP_MENU_CONFIRM, V_KEYBOARD, CT_KB_ENTER, VInputOptions::OncePerFrame(ONCE_ON_RELEASE));
  pInputMap->MapTrigger(VAPP_MENU_BACK, V_KEYBOARD, CT_KB_BACKSP, VInputOptions::OncePerFrame(ONCE_ON_RELEASE));
#endif
}

void VAppWin::UpdateApplicationState()
{
  VAppBase::UpdateApplicationState();

  // Refresh screen when loading
  if (GetAppState() == VAppHelper::AS_SCENE_LOADING)
  {
    Vision::Video.UpdateScreen();
  }
}

void VAppWin::SetupPlatformRootFileSystem()
{
  VAppBase::SetupPlatformRootFileSystem();

  VStaticString<FS_MAX_PATH> szApplicationDir;
  if (!VBaseAppHelpers::GetApplicationDir(szApplicationDir))
  {
    VASSERT_MSG(false, "Unable to determine application directory!");
    return;
  }

  szApplicationDir = VPathHelper::CombineDirAndDir(szApplicationDir.AsChar(), "../../../../");

  const VString& sRoot = m_appConfig.m_sFileSystemRootName;
  if(VFileServeDaemon::IsInitialized())
    Vision::File.AddFileSystem(sRoot, VFileServeDaemon::GetInstance()->CreateFileSystem(sRoot, szApplicationDir));
  else
    Vision::File.AddFileSystem(sRoot, szApplicationDir);

  Vision::File.AddFileSystem("app_data", GetApplicationDataDirectory(), VFileSystemFlags::WRITABLE);
}

VString VAppWin::GetApplicationDataDirectory()
{
  return GetPlatformStorageDirectory();
}

VString VAppWin::GetPlatformStorageDirectory()
{
  VStaticString<FS_MAX_PATH> szApplicationDir;
  if (!VBaseAppHelpers::GetApplicationDir(szApplicationDir))
  {
    VASSERT_MSG(false, "Unable to determine application directory!");
    return "";
  }

  return szApplicationDir.AsChar();
}

VString VAppWin::GetPlatformCacheDirectory()
{
  return GetPlatformStorageDirectory();
}

VAppHelper::VPlatformThreadingModel VAppWin::GetThreadingModel()
{
  VAppHelper::VPlatformThreadingModel model;
  model.m_iNumCoresSkipped = 0;
  model.m_iWorkerThreadCount = 3;
  model.m_bFixedWorkerThreadCpuAssignment = false;
  return model;
}

bool VAppWin::CheckFullscreenResolution(int iAdapter, int desiredX, int desiredY, int* selectedX, int* selectedY)
{
  VASSERT(selectedX && selectedY);

  // by default is the same
  *selectedX = VVIDEO_DEFAULTWIDTH;
  *selectedY = VVIDEO_DEFAULTHEIGHT;

  // Getting the number of display modes
  DEVMODEA deviceMode;
  deviceMode = Vision::Video.GetAdapterMode(iAdapter);
  int nModes = VVideo::GetAdapterModeCount(iAdapter, deviceMode.dmBitsPerPel);

  if (nModes == 0)
    return false;

  // Retrieving the display modes
  VVideoMode* arrayModes = new VVideoMode[nModes];
  memset(arrayModes, 0, sizeof(VVideoMode)*nModes);
  VASSERT(arrayModes != NULL);
  VVideo::EnumAdapterModes(iAdapter, deviceMode.dmBitsPerPel, arrayModes);

  int iError = 1 << 16;
  VVideoMode* pBestFitting = NULL;
  for (int i=0; i<nModes; ++i)
  {
    const int iX = arrayModes[i].m_iXRes;
    const int iY = arrayModes[i].m_iYRes;

    // Same resolution mode exists, returns supported+
    if (iX == desiredX && iY == desiredY)
    {
      *selectedX = desiredX;
      *selectedY = desiredY;
      return true;
    }

    const int iValue = ((iX - desiredX)*(iX - desiredX) + (iY - desiredY)*(iY - desiredY)) / 2; // Mean Square Error
    if (iValue < iError)
    {
      pBestFitting = &arrayModes[i];
      iError = iValue;
    }
  }

  if (pBestFitting != NULL)
  {
    *selectedX = pBestFitting->m_iXRes;
    *selectedY = pBestFitting->m_iYRes;
  }
  V_SAFE_DELETE_ARRAY(arrayModes);

  return false;
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
