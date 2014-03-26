/*
 *
 * Confidential Information of Telekinesys Research Limited (t/a Havok). Not for disclosure or distribution without Havok's
 * prior written consent. This software contains code, techniques and know-how which is confidential and proprietary to Havok.
 * Product and Trade Secret source code contains trade secrets of Havok. Havok Software (C) Copyright 1999-2013 Telekinesys Research Limited t/a Havok. All Rights Reserved. Use of this software is subject to the terms of an end user license agreement.
 *
 */

#include <Vision/Runtime/Framework/VisionApp/Modules/VDebugShadingModes.hpp>
#include <Vision/Runtime/Framework/VisionApp/VAppImpl.hpp>

#include <Vision/Runtime/Engine/Renderer/VisApiSimpleRendererNode.hpp>

V_IMPLEMENT_DYNCREATE(VDebugShadingModes, VAppModule, Vision::GetEngineModule());

VDebugShadingModes::VDebugShadingModes()
  : VAppModule()
  , m_spBackupRendererNode(NULL)
  , m_spDebugShadingShaderLib(NULL)
  , m_spDebugShadingRenderLoop(NULL)
  , m_iCurrentDebugShadingMode(-1)
{
  
}

void VDebugShadingModes::Init()
{
  Vision::Callbacks.OnAfterSceneLoaded += this;
  Vision::Callbacks.OnBeforeSceneUnloaded += this;

  m_debugShadingEffects.Clear();
  m_spDebugShadingShaderLib = NULL;

  m_spDebugShadingShaderLib = Vision::Shaders.LoadShaderLibrary("Shaders\\DebugShadingEffects.ShaderLib");
  if ((m_spDebugShadingShaderLib == NULL) || (m_spDebugShadingShaderLib && !m_spDebugShadingShaderLib->IsLoaded()))
    return;

  VAppMenu* pMainMenu = GetParent()->GetAppModule<VAppMenu>();
  if (pMainMenu == NULL)
    return;
  
  VAppMenuItems items;

  VisShaderFXLibManager_cl &manager(Vision::Shaders.GetShaderFXLibManager());
  // Enumerate all available effects and add them to a collection for later usage
  for (int i=0;i<m_spDebugShadingShaderLib->m_Effects.Count();i++)
  {
    VCompiledEffect *pFX = m_spDebugShadingShaderLib->m_Effects.GetAt(i)->CompileEffect(NULL, manager.m_ShaderInstances);

    // Skip the "NotAvailable" shader, because it is only used for fallback reasons in vForge
    if ((pFX==NULL) || (pFX && VStringHelper::SafeCompare(pFX->GetSourceEffect()->GetName(), "NotAvailable") == 0))
      continue;

    // Use the effect's same as a description
    pFX->SetUserData((void *)pFX->GetSourceEffect()->GetName());

    int iIndex = m_debugShadingEffects.Add(pFX);
    items.Add(VAppMenuItem(pFX->GetSourceEffect()->GetName(), iIndex, 0, true));
  }
  
  m_callbacks = pMainMenu->RegisterGroup("Debug Shading", items, NULL, VAPP_DEFAULT_SORTING_2, false);
  RegisterCallbacks();
}

void VDebugShadingModes::DeInit()
{
  Vision::Callbacks.OnAfterSceneLoaded -= this;
  Vision::Callbacks.OnBeforeSceneUnloaded -= this;
  DeRegisterCallbacks();

  m_spBackupRendererNode = NULL;
  Vision::RenderLoopHelper.SetReplacementRenderLoop(NULL);
  m_spDebugShadingRenderLoop = NULL;
  m_debugShadingEffects.Clear();
  m_spDebugShadingShaderLib = NULL;
}

void VDebugShadingModes::OnHandleCallback(IVisCallbackDataObject_cl* pData)
{
  if (pData->m_pSender == &Vision::Callbacks.OnAfterSceneLoaded)
  {
    Vision::RenderLoopHelper.SetReplacementRenderLoop(NULL);
    m_iCurrentDebugShadingMode = -1;
  }
  else if (pData->m_pSender == &Vision::Callbacks.OnBeforeSceneUnloaded)
  {
    Vision::RenderLoopHelper.SetReplacementRenderLoop(NULL);
    m_iCurrentDebugShadingMode = -1;
    m_spBackupRendererNode = NULL;
  }

  int iIndex = GetCallbackIndex(pData);
  if (iIndex >= 0)
  {
    if (m_iCurrentDebugShadingMode == -1)
    {
      // Backup render node so that the debug rendering can be restored to the original rendering
      m_spBackupRendererNode = Vision::Renderer.GetRendererNode(0);
    }

    // Disable when currently active shading mode is triggered again
    if (m_iCurrentDebugShadingMode == iIndex)
    {
      m_iCurrentDebugShadingMode = -1;
      Vision::RenderLoopHelper.SetReplacementRenderLoop(NULL);
      Vision::Renderer.SetRendererNode(0, m_spBackupRendererNode);
    }
    else
    {
      m_iCurrentDebugShadingMode = iIndex;

      // The debug shading works by replacing the current render loop by a debug shading one which applies the different effects
      if (m_spDebugShadingRenderLoop == NULL)
        m_spDebugShadingRenderLoop = new VisDebugShadingRenderLoop_cl();

      m_spDebugShadingRenderLoop->SetEffect(m_debugShadingEffects.GetAt(m_iCurrentDebugShadingMode));

      // Simple render node base on the main render context which encapsulates the debug shading render loop
      VSimpleRendererNode* pSimpleRendererNode = new VSimpleRendererNode(Vision::Contexts.GetMainRenderContext());
      pSimpleRendererNode->InitializeRenderer();

      Vision::Renderer.SetRendererNode(0, pSimpleRendererNode);
      Vision::RenderLoopHelper.SetReplacementRenderLoop(m_spDebugShadingRenderLoop);
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
