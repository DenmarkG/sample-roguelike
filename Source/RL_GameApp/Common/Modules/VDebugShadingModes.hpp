/*
 *
 * Confidential Information of Telekinesys Research Limited (t/a Havok). Not for disclosure or distribution without Havok's
 * prior written consent. This software contains code, techniques and know-how which is confidential and proprietary to Havok.
 * Product and Trade Secret source code contains trade secrets of Havok. Havok Software (C) Copyright 1999-2013 Telekinesys Research Limited t/a Havok. All Rights Reserved. Use of this software is subject to the terms of an end user license agreement.
 *
 */

#ifndef __V_DEBUG_SHADING_MODES
#define __V_DEBUG_SHADING_MODES

#include <Vision/Runtime/Engine/System/Vision.hpp>
#include <Vision/Runtime/Framework/VisionApp/VAppModule.hpp>

#include <Vision/Runtime/Engine/Renderer/RenderLoop/VisApiDebugShadingRenderLoop.hpp>

/// \brief
///   Application Module which provides various debug shading modes such as showing normal maps, UV layout, etc.
///
/// The module uses Vision's replacement render loop feature to render the current scene with the selected
/// shading mode. The module also adds a 'Debug Shading' group to the VAppMenu from where the user can
/// choose the desired debug shading mode from.
///
/// \ingroup VisionAppFramework
class VDebugShadingModes : public VAppModule
{
  V_DECLARE_DYNCREATE(VDebugShadingModes);

public:
	VDebugShadingModes();
	virtual ~VDebugShadingModes() {}

  virtual void Init() HKV_OVERRIDE;
  virtual void DeInit() HKV_OVERRIDE;

  virtual void OnHandleCallback(IVisCallbackDataObject_cl* pData) HKV_OVERRIDE;

protected:
  IVRendererNodePtr m_spBackupRendererNode;
  VSmartPtr<VShaderEffectLib> m_spDebugShadingShaderLib;
  VRefCountedCollection<VCompiledEffect> m_debugShadingEffects;
  VSmartPtr<VisDebugShadingRenderLoop_cl> m_spDebugShadingRenderLoop;
  int m_iCurrentDebugShadingMode;
};

#endif //__V_DEBUG_SHADING_MODES

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
