/*
 *
 * Confidential Information of Telekinesys Research Limited (t/a Havok). Not for disclosure or distribution without Havok's
 * prior written consent. This software contains code, techniques and know-how which is confidential and proprietary to Havok.
 * Product and Trade Secret source code contains trade secrets of Havok. Havok Software (C) Copyright 1999-2013 Telekinesys Research Limited t/a Havok. All Rights Reserved. Use of this software is subject to the terms of an end user license agreement.
 *
 */

#include <Vision/Runtime/Framework/VisionApp/VAppBase.hpp>

#include <Vision/Runtime/Base/System/Memory/Manager/VSmallBlockMemoryManager.hpp>

#include <Vision/Runtime/Framework/VisionApp/VAppImpl.hpp>
#include <Vision/Runtime/Framework/VisionApp/Helper/VDataDirectoryHelper.hpp>
#include <Vision/Runtime/Framework/VisionApp/Modules/VExitHandler.hpp>

#include <Vision/Runtime/Engine/Renderer/VisApiSimpleRendererNode.hpp>
#include <Vision/Runtime/Engine/System/Resource/IVisApiBackgroundResourceRestorer.hpp>
#include <Vision/Runtime/EnginePlugins/EnginePluginsImport.hpp>

// Define the memory manager.
DEFINE_MEMORYMANAGER(GetDefaultVMemoryManager());

VAppBase* VAppBase::s_instance = NULL;

VisCallback_cl VAppBase::OnAppStateChanged;

VArray<VAppBase::VStartupElement>* VAppBase::s_pStartupModules = NULL;

bool VAppBase::RegisterStartupModule(VStartupModule* pModule, int iPriority)
{
  if (s_pStartupModules == NULL)
    s_pStartupModules = new VArray<VStartupElement>();

  // Sorted insert
  for (int i=0; i<s_pStartupModules->GetSize(); ++i)
  {
    if (iPriority < s_pStartupModules->GetAt(i).m_iPriority)
    {
      s_pStartupModules->InsertAt(i, VStartupElement(pModule, iPriority));
      return true;
    }
  }

  s_pStartupModules->Add(VStartupElement(pModule, iPriority));
  return true;
}

void VAppBase::ProcessStartupModules()
{
  if (s_pStartupModules == NULL)
    return;

  while (s_pStartupModules->GetSize() > 0 && !VAppBase::Get()->WantsToQuit())
  {
    VStartupModule* pModule = s_pStartupModules->GetAt(0).m_pModule;
    s_pStartupModules->RemoveAt(0);

    pModule->Init();

    // Run the startup module as long it returns true
    bool bResult = true;
    while (bResult)
    {
      bResult &= VAppBase::Get()->PlatformRun();
      bResult = bResult && pModule->Run();
    }

    pModule->DeInit();
    delete pModule;
  }

  V_SAFE_DELETE(s_pStartupModules);
}

VAppBase::VAppBase()
  : VisionApp_cl()
  , m_pAppImpl(NULL)
  , m_pResourceRestorer(NULL)
  , m_eAppState(VAppHelper::AS_RUNNING)
{
  VISION_INTER_LINKING_CHECK;

  VASSERT_ALWAYS_MSG(s_instance == NULL, "There must only be one VAppBase instance!");
  s_instance = this;

  Vision::Callbacks.OnBeforeSceneLoaded += this;

  Vision::Callbacks.OnEngineInit += this;
  Vision::Callbacks.OnEngineDeInit += this;
}

VAppBase::~VAppBase()
{ 
  Vision::Callbacks.OnBeforeSceneLoaded -= this;

  Vision::Callbacks.OnEngineInit -= this;
  Vision::Callbacks.OnEngineDeInit -= this;
}

void VAppBase::Execute(VAppImpl* pImpl)
{
  // Early out in case one of the startup modules triggered a quit
  if (WantsToQuit())
    return;

  if(pImpl == NULL)
  {
    hkvLog::FatalError("No implmentation found!");
    return;
  }
  
  m_pAppImpl = pImpl;
	Vision::SetApplication(this);

  // On callback based platforms the remaining code of the execute function
  // is triggered via the corresponding platform specific functions
  if (IsCallbackBased())
    return;

  AppInit();
  {
    // Main application loop (non callback based platforms only)
    bool bRun = true;
    while (bRun)
    {
      bRun = AppRun();
    }
  }
  AppDeInit();
}

bool VAppBase::AppInit()
{
  VASSERT_MSG(m_pAppImpl != NULL, "VAppImpl invalid!");

  // Trigger the user application for possible screen setting changes
  m_pAppImpl->SetupAppConfig(m_appConfig);

  // Set default texture filter mode
  // Note: platform specific code may override this
  Vision::Renderer.SetDefaultTextureFilterMode(FILTER_MIN_MAG_MIP_LINEAR);

  // Setup platform specific stuff
  PlatformInitSettings();
  SetupPlatformRootFileSystem();

  // Setup base data directory and load vision engine plugin which is always required
  SetupBaseDataDirectories();
  VISION_PLUGIN_ENSURE_LOADED(VisionEnginePlugin);

  m_pAppImpl->PreloadPlugins();

  // Initialize engine
  if (!InitEngine())
  { 
    AppInitFailed();
    return false;
  }
  AppInitThreadManager();
  AppAfterEngineInit();
  PlatformMapInput();

  m_pAppImpl->Init();

  return true;
}

bool VAppBase::AppRun()
{
  if (!PlatformRun())
    return false;

  UpdateApplicationState();
  switch(m_eAppState)
  {
  case VAppHelper::AS_SCENE_LOADING:       return true;
  case VAppHelper::AS_SCENE_LOADING_ERROR: return false;
  }

  bool bResult = true;
  bResult &= Run();
  bResult &= m_pAppImpl->Run();
  
  return bResult;
}

bool VAppBase::AppDeInit()
{
  if(!m_pAppImpl)
  {
    return true;
  }

  // Shutdown everything
  // Note that the application implementation gets deleted when Vision::Callbacks.OnEngineDeInit is triggered
  m_pAppImpl->DeInit();

  DeInitEngine();

  Vision::SetApplication(NULL);
  Vision::Shutdown();

  return true;
}

void VAppBase::AppInitThreadManager()
{
  const int iCores = Vision::GetThreadManager()->GetNumberOfProcessors();
  VAppHelper::VPlatformThreadingModel threadingModel = GetThreadingModel();

  // Compute maximum amount of worker threads
  if (threadingModel.m_iWorkerThreadCount <= -1)
    threadingModel.m_iWorkerThreadCount = iCores - threadingModel.m_iNumCoresSkipped;

  Vision::GetThreadManager()->SetThreadCount(threadingModel.m_iWorkerThreadCount);

  if (threadingModel.m_bFixedWorkerThreadCpuAssignment && (iCores > threadingModel.m_iNumCoresSkipped))
  {
    for (int iThread=0; iThread < threadingModel.m_iWorkerThreadCount; iThread++)
    {
      Vision::GetThreadManager()->AssignThreadToProcessor(iThread, iThread % (iCores - threadingModel.m_iWorkerThreadCount) + threadingModel.m_iWorkerThreadCount);
    }
  }
}

void VAppBase::AppInitFailed()
{
  VASSERT(m_pAppImpl != NULL);
  m_pAppImpl->InitFailed();
  PlatformDeInit();
}

void VAppBase::AppAfterEngineInit()
{
  // Preload debug font so its cached even when not used at all.
  Vision::Fonts.DebugFont();

  VASSERT(m_pAppImpl != NULL);
  m_pAppImpl->RegisterAppModule(new VExitHandler);
  m_pAppImpl->AfterEngineInit();
}

void VAppBase::PlatformInit()
{
  VBaseInit();

  VDiskFileStreamCacheManager::SetReadCacheSize(256*1024);

  // Save the startup path. We may need to use it later if we want to make paths specified as 
  // command-line parameters relative to the path the application was started in (as opposed
  // to the path the executable resides in).
  m_sStartupPath = VPathHelper::MakeAbsoluteDir(".");

  // Set the current directory to the EXE dir so the sample can find it's data files
  //(We need to do this since VC2003 sets the project file dir as the default
  // dir and not the EXE. We can change the startup directory in the settings, but it
  // is in a user specific (SUO) file and not in the SLN/VCPROJ files we ship)
  VisionAppHelpers::MakeEXEDirCurrent();
}

void VAppBase::PlatformInitSettings()
{
  VASSERT_MSG(m_pAppImpl != NULL, "VAppImpl invalid!");
  m_appConfig.m_uiInitFlags = m_pAppImpl->SetupEngineInitFlags();

  // Check whether the graphics card supports at least SM 1.1
  VisionAppHelpers::CheckShaderCompatibility(); 
}

void VAppBase::PlatformDeInit()
{
  Vision::SetApplication(NULL);
  Vision::Shutdown();
}

void VAppBase::SetupPlatformRootFileSystem()
{
  if (!VFileAccessManager::IsInitialized())
  {
    VFileAccessManager::Init();
  }
  else
  {
    VFileAccessManager::GetInstance()->ClearSearchPaths();
    VFileAccessManager::GetInstance()->ClearRoots();
  }
}


void VAppBase::SetupBaseDataDirectories()
{
  VString sRoot;
  sRoot.Format(":%s", m_appConfig.m_sFileSystemRootName.AsChar());

  VFileAccessManager::GetInstance()->ClearSearchPaths();
  VFileAccessManager::GetInstance()->AddSearchPath(sRoot);
  VFileAccessManager::GetInstance()->AddSearchPath(sRoot + "/Data/Vision/Base");
  VFileAccessManager::GetInstance()->AddSearchPath(":app_data", VSearchPathFlags::WRITABLE);
}

void VAppBase::OnHandleCallback(IVisCallbackDataObject_cl* pData)
{
  if (pData->m_pSender == &Vision::Callbacks.OnBeforeSceneLoaded)
  {
    m_eAppState = VAppHelper::AS_SCENE_LOADING;
  }
  else if (pData->m_pSender == &Vision::Callbacks.OnLeaveForeground)
  {
    if (m_eAppState == VAppHelper::AS_RUNNING)
    {
      // On WIN32 this event is already triggered inside Run().
#if !defined(WIN32)
      // Draw frame to enable application modules to grab frame buffer
      // content via Vision::Callbacks.OnBeforeSwapBuffers
      Run();
#endif
    }
  }
  else if (pData->m_pSender == &Vision::Callbacks.OnEngineInit)
  {
    Vision::Callbacks.OnLeaveForeground += this;
  }
  else if (pData->m_pSender == &Vision::Callbacks.OnEngineDeInit)
  {
    Vision::Callbacks.OnLeaveForeground -= this;

    VASSERT(m_pAppImpl != NULL);
    m_pAppImpl->EngineDeInit();
    V_SAFE_DELETE(m_pAppImpl);
  }
}

int VAppBase::GetCallbackSortingKey(VCallback* pCallback)
{
  // Modify the priority of the OnLeaveForeground callback to ensure that
  // all application modules also listening to that callback get informed
  // before the VAppBase. Otherwise the application would go to background
  // leaving the application modules uninformed.
  if (pCallback == &Vision::Callbacks.OnLeaveForeground)
    return 1;

  return 0;
}

void VAppBase::OnLoadSceneStatus(int iStatus, float fPercentage)
{
  VisionApp_cl::OnLoadSceneStatus(iStatus, fPercentage);

  if (!m_pAppImpl->GetSceneLoader().IsAborted())
  {
    switch (iStatus)
    {
      case VIS_API_LOADSCENESTATUS_START:
        Vision::Video.SuspendRendering();
        break;

      case VIS_API_LOADMODELSTATUS_START:
      case VIS_API_LOADMODELSTATUS_FINISHED:
      case VIS_API_LOADMODELSTATUS_PROGRESS:
        {
          if (m_eAppState != VAppHelper::AS_SCENE_LOADING)
            return;
        }
    }

    // Skip rendering when in background
    if (m_eAppState == VAppHelper::AS_SUSPENDED)
      return;

    if (!GetLoadingProgress().WantsAbort())
    {
      // ResumeRendering ensures that we have control over the rendering device
      Vision::Video.ResumeRendering();

      VisRenderContext_cl::GetMainRenderContext()->Activate();
      Vision::RenderScreenMasks();
      Vision::Video.UpdateScreen();
    }

    Vision::Video.SuspendRendering();
  }
}

void VAppBase::UpdateApplicationState()
{
  // Scene loading can be triggered via lua script
  if ((m_eAppState == VAppHelper::AS_RUNNING) && IsLoadSceneRequestPending())
  {
    const VLoadSceneRequest& request = GetPendingLoadSceneRequest();
    m_pAppImpl->LoadScene(request.m_settings);
    ClearLoadSceneRequest();
  }

  if (m_eAppState == VAppHelper::AS_SUSPENDED || m_eAppState == VAppHelper::AS_RUNNING)
    return;

  // Restore background resources first before continuing the loading process
  if (m_pResourceRestorer != NULL)
  {
    VASSERT(m_eAppState == VAppHelper::AS_SCENE_LOADING);
    m_pResourceRestorer->Tick();
  }
  // Check scene loading state
  else if (!m_pAppImpl->GetSceneLoader().IsFinished() && !m_pAppImpl->GetSceneLoader().IsInErrorState())
  {
    m_pAppImpl->GetSceneLoader().Tick();
    m_eAppState = VAppHelper::AS_SCENE_LOADING;
  }
  else if (m_eAppState == VAppHelper::AS_SCENE_LOADING)
  {
    // In case the scene has not been found we treat this as loading done, thus the previous scene or no scene will be active
    if (m_pAppImpl->GetSceneLoader().IsNotFound())
    {
      m_eAppState = VAppHelper::AS_RUNNING;
      m_pAppImpl->AfterSceneLoaded(false);
    }
    else if (m_pAppImpl->GetSceneLoader().IsInErrorState())
    {
      m_eAppState = VAppHelper::AS_SCENE_LOADING_ERROR;
      VASSERT_MSG(false, "Loading error!");
    }
    else
    {
      m_eAppState = VAppHelper::AS_RUNNING;
      m_pAppImpl->AfterSceneLoaded(true);
    }
  }
}

void VAppBase::SetAppState(VAppHelper::VApplicationState eAppState)
{
  if (eAppState == m_eAppState)
    return;

  VAppStateRef eOldState = m_eAppState;
  m_eAppState = eAppState;

  VAppStateChangedObject data(&OnAppStateChanged, eOldState, m_eAppState);
  OnAppStateChanged.TriggerCallbacks(&data);
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
