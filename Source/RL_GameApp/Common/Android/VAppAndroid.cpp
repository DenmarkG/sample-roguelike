/*
 *
 * Confidential Information of Telekinesys Research Limited (t/a Havok). Not for disclosure or distribution without Havok's
 * prior written consent. This software contains code, techniques and know-how which is confidential and proprietary to Havok.
 * Product and Trade Secret source code contains trade secrets of Havok. Havok Software (C) Copyright 1999-2013 Telekinesys Research Limited t/a Havok. All Rights Reserved. Use of this software is subject to the terms of an end user license agreement.
 *
 */

#include <Vision/Runtime/Framework/VisionApp/Android/VAppAndroid.hpp>
#include <Vision/Runtime/Framework/VisionApp/VAppImpl.hpp>

#include <Vision/Runtime/Base/System/IO/FileSystems/VFileServeDaemon.hpp>

VAppAndroid::VAppAndroid(struct android_app* state)
  : VAppMobile()
  , m_sCacheDirectory()
  , m_sApkDirectory()
  , m_sSdCardDirectory()
{
  AndroidApplication = state;
}

VAppAndroid::~VAppAndroid(void)
{
}

void VAppAndroid::PlatformInit()
{
  char szApkDir[FS_MAX_PATH];
  char szAppDataDir[FS_MAX_PATH];
  char szSdCardDir[FS_MAX_PATH];
  char szCacheDir[FS_MAX_PATH];
  InitAndroidNativeEnvironment(szApkDir, szAppDataDir, szSdCardDir, szCacheDir);

  m_sApkDirectory = szApkDir;
  m_sAppDataDirectory = szAppDataDir;
  m_sSdCardDirectory = szSdCardDir;
  m_sCacheDirectory = szCacheDir;

  VAppMobile::PlatformInit();
}

void VAppAndroid::PlatformInitSettings()
{
#if !defined(FORCE_TRILINEAR_FILTERING)
  Vision::Renderer.SetDefaultTextureFilterMode(FILTER_MIN_MAG_LINEAR_MIP_POINT);
#endif

  VAppMobile::PlatformInitSettings();
}

void VAppAndroid::PlatformMapInput()
{
  VInputMap* pInputMap = m_pAppImpl->GetInputMap();
  pInputMap->MapTrigger(VAPP_EXIT, VInputManagerAndroid::GetKeyInput(), CT_PAD_ANDROID_BACK, VInputOptions::OncePerFrame(ONCE_ON_RELEASE));
  pInputMap->MapTrigger(VAPP_MENU, VInputManagerAndroid::GetKeyInput(), CT_PAD_ANDROID_MENU, VInputOptions::OncePerFrame(ONCE_ON_RELEASE));
}

bool VAppAndroid::PlatformRun()
{
  return PollAndroidNativeEnvironment();
}

void VAppAndroid::PlatformDeInit()
{
  DeinitAndroidNativeEnvironment();
}

void VAppAndroid::UpdateApplicationState()
{
  VAppMobile::UpdateApplicationState();
  
  // Refresh screen when loading
  if (GetAppState() == VAppHelper::AS_SCENE_LOADING)
  {
    // TODO: Always allow the application to exit on android if the app is loading
    //if (GetInputMap()->GetTrigger(EXIT)) 
    //{
    //  m_sceneLoader.Close();
    //  m_sceneLoader.OnAbort();
    //  m_appState = AS_LOADING_ERROR;
    //  return m_appState;
    //}

    // We have to draw the screen masks here to ensure that we actually fill the 
    // frame buffer every time the API is called since the OS clears the frame 
    // buffer itself.
    Vision::Video.ResumeRendering();

    VisRenderContext_cl::GetMainRenderContext()->Activate();
    Vision::RenderScreenMasks();
    Vision::Video.UpdateScreen();
  }
}

void VAppAndroid::SetupPlatformRootFileSystem()
{
  VAppMobile::SetupPlatformRootFileSystem();

  VString sDataDirPrefix;
  sDataDirPrefix.Format("%s?assets/", m_sApkDirectory.AsChar());

  const VString& sRoot = m_appConfig.m_sFileSystemRootName;
  if(VFileServeDaemon::IsInitialized())
    VFileAccessManager::GetInstance()->SetRoot(sRoot, VFileServeDaemon::GetInstance()->CreateFileSystem(sRoot, sDataDirPrefix));
  else
    VFileAccessManager::GetInstance()->SetRoot(sRoot, sDataDirPrefix);

  VFileAccessManager::GetInstance()->SetRoot("app_data", GetApplicationDataDirectory(), VFileSystemFlags::WRITABLE);
}

VString VAppAndroid::GetApplicationDataDirectory()
{
  return m_sAppDataDirectory;
}

VString VAppAndroid::GetPlatformStorageDirectory()
{
  return m_sSdCardDirectory;
}

VString VAppAndroid::GetPlatformCacheDirectory()
{
  return m_sCacheDirectory;
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
