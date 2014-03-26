/*
 *
 * Confidential Information of Telekinesys Research Limited (t/a Havok). Not for disclosure or distribution without Havok's
 * prior written consent. This software contains code, techniques and know-how which is confidential and proprietary to Havok.
 * Product and Trade Secret source code contains trade secrets of Havok. Havok Software (C) Copyright 1999-2013 Telekinesys Research Limited t/a Havok. All Rights Reserved. Use of this software is subject to the terms of an end user license agreement.
 *
 */

#ifndef __V_DEBUG_OPTIONS
#define __V_DEBUG_OPTIONS

#include <Vision/Runtime/Engine/System/Vision.hpp>
#include <Vision/Runtime/Framework/VisionApp/VAppModule.hpp>

class VGraphObject;

/// \brief
///   Module for controlling different debugging options such as show frame rate, toggle
///   wireframe rendering, reload resources, etc.
///
/// The module adds the various options to the VAppMenu, thus the options can easily be
/// triggered/enabled by the user.
///
/// \ingroup VisionAppFramework
class VDebugOptions : public VAppModule
{
  V_DECLARE_DYNCREATE(VDebugOptions);

public:
	VDebugOptions();
	virtual ~VDebugOptions() {}

  virtual void Init() HKV_OVERRIDE;
  virtual void DeInit() HKV_OVERRIDE;

  virtual void OnHandleCallback(IVisCallbackDataObject_cl* pData) HKV_OVERRIDE;

  void SetFrameRateVisible(bool bVisible);
  inline bool IsFrameRateVisible() const { return m_bFpsVisible; }

  void SetWireframe(bool bWireframe);
  inline bool IsWireframe() const { return Vision::Renderer.GetWireframeMode(); }

  inline float GetCurrentFrameRate() const { return m_fCurrentFps; }
  inline float GetCurrentFrameTime() const { return m_fCurrentFrameTime; }

protected:
  enum VDebugOptionEntries
  {
    OPTION_FPS = 0,
    OPTION_WIREFRAME,
    OPTION_RELOAD_RESOURCES,
    OPTION_TIME_STEP_GRAPH,
    OPTION_MULTITOUCH,
    OPTION_SAVE_SCREENSHOT
  };

  int m_iFrameCounter;
  float m_fTimeAccumulator;
  float m_fCurrentFrameTime;
  float m_fCurrentFps;

  bool m_bFpsVisible;
  bool m_bSaveScreenshot;
  bool m_bTouchAreaDebug;

  VGraphObject* m_pTimeStepGraph;

  VArray<VisCallback_cl*> m_debugInfos;
};

#endif //__V_DEBUG_OPTIONS

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
