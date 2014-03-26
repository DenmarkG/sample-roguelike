/*
 *
 * Confidential Information of Telekinesys Research Limited (t/a Havok). Not for disclosure or distribution without Havok's
 * prior written consent. This software contains code, techniques and know-how which is confidential and proprietary to Havok.
 * Product and Trade Secret source code contains trade secrets of Havok. Havok Software (C) Copyright 1999-2013 Telekinesys Research Limited t/a Havok. All Rights Reserved. Use of this software is subject to the terms of an end user license agreement.
 *
 */

#include <Vision/Runtime/Framework/VisionApp/VAppImpl.hpp>
#include <Vision/Runtime/Framework/VisionApp/Helper/VDataDirectoryHelper.hpp>

#include <Vision/Runtime/Base/System/IO/FileSystems/VFileServeDaemon.hpp>

#include <Vision/Runtime/Framework/VisionApp/Modules/VDefaultMenu.hpp>
#include <Vision/Runtime/Framework/VisionApp/Modules/VLoadingScreen.hpp>
#include <Vision/Runtime/Framework/VisionApp/Modules/VRestoreScreen.hpp>
#include <Vision/Runtime/Framework/VisionApp/Modules/VDebugOptions.hpp>
#include <Vision/Runtime/Framework/VisionApp/Modules/VDebugShadingModes.hpp>
#include <Vision/Runtime/Framework/VisionApp/Modules/VDebugProfiling.hpp>
#include <Vision/Runtime/Framework/VisionApp/Modules/VLogoOverlay.hpp>

#include <Vision/Runtime/EnginePlugins/EnginePluginsImport.hpp>

VInputMap* VAppImpl::s_pInputMap = NULL;

VAppImpl::VAppImpl() : m_pSceneLoader(NULL)
{
  m_pSceneLoader = new VSceneLoader();

  VASSERT_MSG(s_pInputMap == NULL, "Input map already initialized!");
  s_pInputMap = new VInputMap(VAPP_INPUT_CONTROL_LAST_ELEMENT + 1 + VAPP_INPUT_CONTROL_USER_SPACE, VAPP_INPUT_CONTROL_ALTERNATIVES);
  
  m_spContext = new VAppMenuContext;
}

VAppImpl::~VAppImpl()
{
  m_spContext = NULL;

  V_SAFE_DELETE(m_pSceneLoader);
  V_SAFE_DELETE(s_pInputMap);

  // Clear app modules back to front because of dependencies
  const int iCount = m_appModules.Count();
  for (int i=iCount - 1; i>=0; --i)
    m_appModules.GetAt(i)->DeInit();
  m_appModules.Clear();
}

unsigned int VAppImpl::SetupEngineInitFlags()
{
  return VAPP_INIT_DEFAULTS;
}

void VAppImpl::AfterEngineInit()
{
  // Default application modules
  RegisterAppModule(new VDefaultMenu);
  RegisterAppModule(new VLoadingScreen);
  RegisterAppModule(new VRestoreScreen);
  RegisterAppModule(new VDebugOptions);
  RegisterAppModule(new VDebugShadingModes);
  RegisterAppModule(new VDebugProfiling);
  RegisterAppModule(new VLogoOverlay);
}

bool VAppImpl::Run()
{
	return true;
}

void VAppImpl::SetupScene(const VisAppLoadSettings& sceneSettings)
{
  if (sceneSettings.m_bReplaceSearchPaths)
  {
    VAppBase::Get()->SetupBaseDataDirectories();

    // Custom workspace root
    if(!VFileServeDaemon::IsInitialized())
    {
      if (!sceneSettings.m_sWorkspaceRoot.IsEmpty())
        VFileAccessManager::GetInstance()->SetRoot("workspace", sceneSettings.m_sWorkspaceRoot);
    }
    else
    {
      // When FileServe is enabled, the workspace is configured at the host side - so we simply mount a new FileServeFileSystem at ":workspace".
      // If a custom workspace is set, we use it as the package fallback location.
      VFileAccessManager::GetInstance()->SetRoot("workspace", VFileServeDaemon::GetInstance()->CreateFileSystem("workspace", sceneSettings.m_sWorkspaceRoot));
    }

    // Custom search paths
    const VArray<VString>& dataDirs = sceneSettings.m_customSearchPaths;
    for (int i=0; i<dataDirs.GetSize(); ++i)
      VFileAccessManager::GetInstance()->AddSearchPath(dataDirs[i].AsChar());
  }

  // Manifest file
  if (sceneSettings.m_bProcessManifestFile)
    VDataDirectoryHelper::ProcessManifestFile(sceneSettings.m_bSearchPathsFromManifest, sceneSettings.m_bPluginsFromManifest);

  const VString& sSceneName = sceneSettings.m_sSceneName;
  VDataDirectoryHelper::SelectAssetProfile(sSceneName, sceneSettings.m_bAssetProfileFallback);
}

bool VAppImpl::LoadScene(const VisAppLoadSettings& sceneSettings)
{
  if (!m_pSceneLoader->IsFinished())
    return false;

  VAppMenu* pMenu = GetAppModule<VAppMenu>();
  if (pMenu)
    pMenu->Reset();

  // Setup data directories, process manifest file, load plugins
  SetupScene(sceneSettings);

  // Skip loading if scene name is not valid
  const VString& sSceneName = sceneSettings.m_sSceneName;
  if (sSceneName.IsEmpty())
    return true;

  VString szFullName(sSceneName);
  if (!VFileHelper::HasExtension(szFullName.AsChar(), "vscene"))
    szFullName += ".vscene";

  // Trigger changed event on the main camera to ensure that it gets added to the new
  // visibility collector of the new scene
  Vision::Camera.GetMainCamera()->GetVisData()->OnChanged();

  // Finally load the scene with the given name
  if (!m_pSceneLoader->LoadScene(szFullName.AsChar(), sceneSettings.m_uiSceneLoaderFlags))
  {
    hkvLog::Error(m_pSceneLoader->GetLastError());
    return false;
  }

  if(m_pSceneLoader->IsAborted())
    return false;

  return true;
}

void VAppImpl::RegisterAppModule(VAppModule* pModule)
{
  VASSERT(pModule != NULL);

  // Don't add modules more than once
  if (m_appModules.Find(pModule) < 0)
  {
    m_appModules.Add(pModule);
    pModule->SetParent(this);
    pModule->Init();
  }
}

void VAppImpl::DeRegisterAppModule(VAppModule* pModule)
{
  const int iIndex = m_appModules.Find(pModule);
  if (iIndex >= 0)
  {
    pModule->DeInit();
    m_appModules.RemoveAt(iIndex);
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
