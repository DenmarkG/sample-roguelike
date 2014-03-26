/*
 *
 * Confidential Information of Telekinesys Research Limited (t/a Havok). Not for disclosure or distribution without Havok's
 * prior written consent. This software contains code, techniques and know-how which is confidential and proprietary to Havok.
 * Product and Trade Secret source code contains trade secrets of Havok. Havok Software (C) Copyright 1999-2013 Telekinesys Research Limited t/a Havok. All Rights Reserved. Use of this software is subject to the terms of an end user license agreement.
 *
 */

#include <Vision/Runtime/Framework/VisionApp/Modules/VDebugOptions.hpp>
#include <Vision/Runtime/Framework/VisionApp/VAppImpl.hpp>

#include <Vision/Runtime/Framework/VisionApp/Helper/VScreenShotHelper.hpp>
#include <Vision/Runtime/EnginePlugins/VisionEnginePlugin/Rendering/Profiling/VGraphObject.hpp>

V_IMPLEMENT_DYNCREATE(VDebugOptions, VAppModule, Vision::GetEngineModule());

#if defined(WIN32)
  #define TOGGLE_FPS VAPP_INPUT_CONTROL_LAST_ELEMENT - 9
  #define TOGGLE_WIREFRAME VAPP_INPUT_CONTROL_LAST_ELEMENT - 8
#endif

/// \brief
///   Curve Updater which gives unfiltered time difference values.
class VUnfilteredTimeDiffUpdater : public VCurveUpdater
{
public:
  void Update(VArray<float>& values) { values.Append(Vision::GetTimer()->GetUnfilteredTimeDifference()); }
};

/// \brief
///   Curve Updater which gives filtered time difference values.
class VFilteredTimeDiffUpdater : public VCurveUpdater
{
public:
  void Update(VArray<float>& values) { values.Append(Vision::GetTimer()->GetTimeDifference()); }
};

VDebugOptions::VDebugOptions()
  : VAppModule()
  , m_iFrameCounter(0)
  , m_fTimeAccumulator(0.0f)
  , m_fCurrentFrameTime(0.0f)
  , m_fCurrentFps(0.0f)
  , m_bFpsVisible(false)
  , m_bSaveScreenshot(false)
  , m_bTouchAreaDebug(false)
  , m_pTimeStepGraph(NULL)
{

}

void VDebugOptions::Init()
{
  Vision::Callbacks.OnUpdateSceneBegin += this;
  Vision::Callbacks.OnBeforeSwapBuffers += this;
  Vision::Callbacks.OnRenderHook += this;

  // Setup graph for displaying un-/filtered time steps
  VGraphProps timeStepGraphProps;
  timeStepGraphProps.vPosition.set(-0.85f, -0.3f);  
  timeStepGraphProps.fWidth = 0.25f;
  timeStepGraphProps.fHeight = 0.25f;  
  timeStepGraphProps.iResolution = 64; 
  timeStepGraphProps.bRangeAdaptation = true;
  m_pTimeStepGraph = new VGraphObject(timeStepGraphProps);
  m_pTimeStepGraph->AddCurve("Unfiltered Time Step", VColorRef(0, 255, 0), new VUnfilteredTimeDiffUpdater);
  m_pTimeStepGraph->AddCurve("Filtered Time Step", VColorRef(255, 0, 0), new VFilteredTimeDiffUpdater);
  m_pTimeStepGraph->Init();
  m_pTimeStepGraph->SetVisible(false);

#if defined(WIN32)
  GetParent()->GetInputMap()->MapTrigger(TOGGLE_FPS, VInputManager::GetKeyboard(), CT_KB_F2, VInputOptions::Once(ONCE_ON_RELEASE));
  GetParent()->GetInputMap()->MapTrigger(TOGGLE_WIREFRAME, VInputManager::GetKeyboard(), CT_KB_F3, VInputOptions::Once(ONCE_ON_RELEASE));
#endif

  VAppMenu* pMainMenu = GetParent()->GetAppModule<VAppMenu>();
  if (pMainMenu == NULL)
    return;

  // General Debug Options
  //  Note: OPTION_FPS, OPTION_WIREFRAME, and OPTION_RELOAD_RESOURCES are added directly to the menu's root, the other options
  //        are added to the menu's root as a group called 'Debug Options'
  m_callbacks.Append(pMainMenu->RegisterItem(VAppMenuItem("Toggle FPS Display", OPTION_FPS, VAPP_DEFAULT_SORTING_0, true)));

  // wireframe rendering is not supported on GLES2
#if !defined(_VR_GLES2)
  m_callbacks.Append(pMainMenu->RegisterItem(VAppMenuItem("Wireframe", OPTION_WIREFRAME, VAPP_DEFAULT_SORTING_0 + 1, true)));
#endif

  m_callbacks.Append(pMainMenu->RegisterItem(VAppMenuItem("Reload Modified Resources", OPTION_RELOAD_RESOURCES, VAPP_DEFAULT_SORTING_0 + 2, false)));

  VAppMenuItems items;
  items.Add(VAppMenuItem("Show Time Step Graph", OPTION_TIME_STEP_GRAPH, 0, true));
  items.Add(VAppMenuItem("Save Screenshot", OPTION_SAVE_SCREENSHOT, 0, false));
#if defined(SUPPORTS_MULTITOUCH)
  items.Add(VAppMenuItem("Touch Area Debug Rendering", OPTION_MULTITOUCH, 0, true));
#endif
  m_callbacks.Append(pMainMenu->RegisterGroup("Debug Options", items, NULL, VAPP_DEFAULT_SORTING_0 + 3, true));
  RegisterCallbacks();

  // Debug Render Flags
  items.RemoveAll();
  items.Add(VAppMenuItem("Display Object Triangle Count", DEBUGRENDERFLAG_OBJECT_TRIANGLECOUNT, 0, true));
  items.Add(VAppMenuItem("Display Object Visibility BoundingBox", DEBUGRENDERFLAG_OBJECT_VISBBOX, 0, true));
  items.Add(VAppMenuItem("Display Object vis. Area Assignment", DEBUGRENDERFLAG_OBJECT_VISIBILITYZONES, 0, true));
  items.Add(VAppMenuItem("Display Light Influence BoundingBox", DEBUGRENDERFLAG_LIGHT_INFLUENCEBOX, 0, true));
  items.Add(VAppMenuItem("Display Trace Lines", DEBUGRENDERFLAG_TRACELINES, 0, true));
  items.Add(VAppMenuItem("Display Visibility Objects", DEBUGRENDERFLAG_VISIBILITYOBJECTS, 0, true));
  items.Add(VAppMenuItem("Display Portals", DEBUGRENDERFLAG_PORTALS, 0, true));
  items.Add(VAppMenuItem("Display Visibility Zones", DEBUGRENDERFLAG_VISIBILITYZONES, 0, true));
  items.Add(VAppMenuItem((Vision::GetScriptManager() != NULL) ? "Scripting Statistics" : "Scripting Statistics (no script man.)", DEBUGRENDERFLAG_SCRIPTSTATISTICS, 0, true));
  items.Add(VAppMenuItem("Display Object Render Order", DEBUGRENDERFLAG_OBJECTRENDERORDER, 0, true));
  items.Add(VAppMenuItem("Display Thread Workload", DEBUGRENDERFLAG_THREADWORKLOAD, 0, true));
  items.Add(VAppMenuItem("Display Streaming Zones", DEBUGRENDERFLAG_ZONES, 0, true));
  items.Add(VAppMenuItem("Display Resource Stats", DEBUGRENDERFLAG_RESOURCE_STATISTICS, 0, true));
  items.Add(VAppMenuItem("Display Memory Stats", DEBUGRENDERFLAG_MEMORY_STATISTICS, 0, true));

  m_debugInfos = pMainMenu->RegisterGroup("Debug Infos", items, "Debug Options");
  RegisterCallbacks(m_debugInfos);
}

void VDebugOptions::DeInit()
{
  Vision::Callbacks.OnUpdateSceneBegin -= this;
  Vision::Callbacks.OnBeforeSwapBuffers -= this;
  Vision::Callbacks.OnRenderHook -= this;

  DeRegisterCallbacks();
  DeRegisterCallbacks(m_debugInfos);

  V_SAFE_DELETE(m_pTimeStepGraph);
}

void VDebugOptions::OnHandleCallback(IVisCallbackDataObject_cl* pData)
{
  if (pData->m_pSender == &Vision::Callbacks.OnUpdateSceneBegin)
  {
#if defined(WIN32)
    if (GetParent()->GetInputMap()->GetTrigger(TOGGLE_FPS))
    {
      SetFrameRateVisible(!IsFrameRateVisible());
    }
    else if (GetParent()->GetInputMap()->GetTrigger(TOGGLE_WIREFRAME))
    {
      SetWireframe(!IsWireframe());
    }
#endif

    // FPS accumulation
    {
      m_iFrameCounter++;
      m_fTimeAccumulator += Vision::GetUITimer()->GetTimeDifference();

      if (m_fTimeAccumulator >= 1.0f)
      {
        m_fCurrentFrameTime = m_fTimeAccumulator / m_iFrameCounter;
        m_fCurrentFps = m_iFrameCounter / m_fTimeAccumulator;

        m_fTimeAccumulator = 0.0f;
        m_iFrameCounter = 0;
      }
    }

    if (m_bFpsVisible)
      Vision::Message.Print(1, 10, Vision::Video.GetYRes() - 35, "FPS : %.1f\nFrame Time : %.2f", m_fCurrentFps, m_fCurrentFrameTime * 1000.0f);
  }
  else if (pData->m_pSender == &Vision::Callbacks.OnBeforeSwapBuffers)
  {
    if (m_bSaveScreenshot)
    {
      VScreenShotHelper helper;
      helper.Capture();
      if (helper.PendingDataInBuffer())
      {
        if (helper.SaveBufferToFile("", NULL, 1.0f, 1.0f))
          Vision::Message.Add(0, "Screenshot saved to \"%s\".\n", helper.GetScreenShotPath());
        else
          Vision::Message.Add(0, "Screenshot could not be saved.\n");
      }

      // Re-enable the VAppMenu again
      VAppMenu* pMainMenu = GetParent()->GetAppModule<VAppMenu>();
      if (pMainMenu)
        pMainMenu->SetVisible(true);

      m_bSaveScreenshot = false;
    }
  }
  else if (pData->m_pSender == &Vision::Callbacks.OnRenderHook)
  {
    VisRenderHookDataObject_cl *pRenderHookData = (VisRenderHookDataObject_cl *)pData;
    if (pRenderHookData->m_iEntryConst == VRH_PRE_SCREENMASKS)
    {
      // Debug drawing of all visible touch areas.
#if defined(SUPPORTS_MULTITOUCH)
      if (m_bTouchAreaDebug)
      {
        IVMultiTouchInput* pMultiTouchInput = NULL;
        pMultiTouchInput = static_cast<IVMultiTouchInput*>(&VInputManager::GetInputDevice(INPUT_DEVICE_TOUCHSCREEN));
        VPListT<VTouchArea> touchAreas = pMultiTouchInput->GetTouchAreas();

        const float fBorderWidth = 3.0f;
        VSimpleRenderState_t alphaState(VIS_TRANSP_ALPHA, RENDERSTATEFLAG_FRONTFACE|RENDERSTATEFLAG_NOWIREFRAME|RENDERSTATEFLAG_ALWAYSVISIBLE);

        IVRender2DInterface *pRI = Vision::RenderLoopHelper.BeginOverlayRendering();
        {
          for (int i=0; i<touchAreas.GetLength(); ++i)
          {
            const VRectanglef& rect = touchAreas.Get(i)->GetArea();
            const VColorRef color = touchAreas.Get(i)->GetTouchPointIndex() < 0 ? VColorRef(0, 255, 0, 64) : VColorRef(0, 255, 0, 96);
            pRI->DrawSolidQuad(rect.m_vMin, rect.m_vMax, color, alphaState);

            pRI->DrawSolidQuad(rect.m_vMin, hkvVec2(rect.m_vMax.x, rect.m_vMin.y + fBorderWidth), VColorRef(0, 255, 0, 255), alphaState);
            pRI->DrawSolidQuad(hkvVec2(rect.m_vMin.x, rect.m_vMax.y - fBorderWidth), rect.m_vMax, VColorRef(0, 255, 0, 255), alphaState);
            pRI->DrawSolidQuad(hkvVec2(rect.m_vMin.x, rect.m_vMin.y + fBorderWidth), hkvVec2(rect.m_vMin.x + fBorderWidth, rect.m_vMax.y - fBorderWidth), VColorRef(0, 255, 0, 255), alphaState);
            pRI->DrawSolidQuad(hkvVec2(rect.m_vMax.x - fBorderWidth, rect.m_vMin.y + fBorderWidth), hkvVec2(rect.m_vMax.x, rect.m_vMax.y - fBorderWidth), VColorRef(0, 255, 0, 255), alphaState);
          }
        }
        Vision::RenderLoopHelper.EndOverlayRendering();
      }
#endif
    }
  }

  int iIndex = GetCallbackIndex(pData);
  if (iIndex >= 0)
  {
    if (iIndex == OPTION_FPS)
    {
      m_bFpsVisible = !m_bFpsVisible;
    }
    else if (iIndex == OPTION_WIREFRAME)
    {
      if (Vision::Renderer.GetWireframeMode())
        Vision::Renderer.SetWireframeMode(false);
      else
        Vision::Renderer.SetWireframeMode(true);
    }
    else if (iIndex == OPTION_RELOAD_RESOURCES)
    {
      int iCount = Vision::ResourceSystem.ReloadModifiedResourceFiles(NULL, VURO_HOT_RELOAD);       

      // Clear effect caches so that material shaders will be re-created (not re-used).
      Vision::Shaders.GetShaderFXLibManager().ResetCompiledEffectCaches();

      // Reassign all material shaders.
      Vision::Shaders.ReloadAllShaderAssignmentFiles();

      Vision::Message.Add(1, "%i resources were outdated and have been reloaded.", iCount);
    }
    else if (iIndex == OPTION_TIME_STEP_GRAPH)
    {
      m_pTimeStepGraph->SetVisible(!m_pTimeStepGraph->IsVisible());
    }
#if defined(SUPPORTS_MULTITOUCH)
    else if (iIndex == OPTION_MULTITOUCH)
    {
      m_bTouchAreaDebug = !m_bTouchAreaDebug;
    }
#endif
    else if (iIndex == OPTION_SAVE_SCREENSHOT)
    {
      m_bSaveScreenshot = true;

      // We don't want the menu to be visible in the screenshot
      VAppMenu* pMainMenu = GetParent()->GetAppModule<VAppMenu>();
      if (pMainMenu != NULL)
        pMainMenu->SetVisible(false);
    }
  }

  iIndex = GetCallbackIndex(m_debugInfos, pData);
  if (iIndex >= 0)
    Vision::Profiling.ToggleDebugRenderFlags((unsigned int)iIndex);
}

void VDebugOptions::SetFrameRateVisible(bool bVisible)
{
  m_bFpsVisible = bVisible;

  VAppMenu* pMainMenu = GetParent()->GetAppModule<VAppMenu>();
  if (pMainMenu != NULL)
  {
    pMainMenu->SetItemCheckState("Toggle FPS Display", m_bFpsVisible);
  }
}

void VDebugOptions::SetWireframe(bool bWireframe)
{  
  Vision::Renderer.SetWireframeMode(bWireframe);

  VAppMenu* pMainMenu = GetParent()->GetAppModule<VAppMenu>();
  if (pMainMenu != NULL)
  {
    pMainMenu->SetItemCheckState("Wireframe", bWireframe);
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
