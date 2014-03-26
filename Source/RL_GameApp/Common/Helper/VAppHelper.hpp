/*
 *
 * Confidential Information of Telekinesys Research Limited (t/a Havok). Not for disclosure or distribution without Havok's
 * prior written consent. This software contains code, techniques and know-how which is confidential and proprietary to Havok.
 * Product and Trade Secret source code contains trade secrets of Havok. Havok Software (C) Copyright 1999-2013 Telekinesys Research Limited t/a Havok. All Rights Reserved. Use of this software is subject to the terms of an end user license agreement.
 *
 */

#ifndef __V_APP_BASE_HELPER
#define __V_APP_BASE_HELPER

#include <Vision/Runtime/Base/VBase.hpp>
#include <Vision/Runtime/Engine/System/Vision.hpp>
#include <Vision/Runtime/EnginePlugins/VisionEnginePlugin/Scene/VSceneLoader.hpp>

/// \brief
///   Helper class used by the application framework.
///
/// \ingroup VisionAppFramework
class VAppHelper
{
public:
  /// \brief
  ///   VAppBase's application state.
  enum VApplicationState
  {
    AS_SCENE_LOADING,            ///< Loading is not yet finished
    AS_SCENE_LOADING_ERROR,      ///< Error during loading
    AS_RUNNING,                  ///< Loading is completed
    AS_SUSPENDED,                ///< Application is currently in background  
  };

  /// \brief
  ///   Helper structure to describe a platform's threading model.
  struct VPlatformThreadingModel
  {
    VPlatformThreadingModel() : m_iWorkerThreadCount(1) , m_iNumCoresSkipped(0) , m_bFixedWorkerThreadCpuAssignment(false) {}
    int   m_iWorkerThreadCount;
    int   m_iNumCoresSkipped;
    bool  m_bFixedWorkerThreadCpuAssignment;
  };

  /// \brief
  ///   Static helper function to create and attach a shadow map component to the passed light source using default parameters.
  /// 
  /// When bStatus is set to true, this function will attach a shadow map component of the appropriate type
  /// to the passed light source using some default parameter values. Note that this convenience function
  /// will only support renderer node index 0.
  ///
  /// \param pLight
  ///   Light source to which to attach the shadow map component
  /// 
  /// \param bStatus
  ///   When set to true, a new shadow map component will be created and attached to the light if there
  ///   is no shadow map component attached to the light source yet. If set to false and the light 
  ///   has a shadow map component attached, this shadow map component will be detached from the light source.
  static void SetShadowsForLight(VisLightSource_cl *pLight, bool bStatus);

  /// \brief
  ///   Static helper function to create a forward rendering system with default parameters.
  static void CreateForwardRenderer();

  /// \brief
  ///   Static helper function to destroy the forward rendering system previously created with CreateForwardRenderer().
  static void DestroyForwardRenderer();

  /// \brief
  ///   Returns a platform dependent scaling factor for UI.
  static float GetUIScalingFactor();
};

typedef const VAppHelper::VApplicationState& VAppStateRef;

/// \brief
///   Callback object used by the VAppBase to inform listeners about application state changes.
class VAppStateChangedObject : public IVisCallbackDataObject_cl
{
public:

  VAppStateChangedObject(VisCallback_cl *pSender, VAppStateRef eOldState, VAppStateRef eNewState)
    : IVisCallbackDataObject_cl(pSender) , m_eOldState(eOldState) , m_eNewState(eNewState) {}

  VAppHelper::VApplicationState m_eOldState;
  VAppHelper::VApplicationState m_eNewState;
};

#endif //__V_APP_BASE_HELPER

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
