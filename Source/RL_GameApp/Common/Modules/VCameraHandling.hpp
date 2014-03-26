/*
 *
 * Confidential Information of Telekinesys Research Limited (t/a Havok). Not for disclosure or distribution without Havok's
 * prior written consent. This software contains code, techniques and know-how which is confidential and proprietary to Havok.
 * Product and Trade Secret source code contains trade secrets of Havok. Havok Software (C) Copyright 1999-2013 Telekinesys Research Limited t/a Havok. All Rights Reserved. Use of this software is subject to the terms of an end user license agreement.
 *
 */

#ifndef __V_CAMERA_HANDLING_HPP
#define __V_CAMERA_HANDLING_HPP

#include <Vision/Runtime/Engine/System/Vision.hpp>
#include <Vision/Runtime/Framework/VisionApp/VAppModule.hpp>
#include <Vision/Runtime/EnginePlugins/VisionEnginePlugin/Input/VFreeCamera.hpp>

class VOrbitCamera;
class CameraPositionEntity;
class PathCameraEntity;

/// \brief
///   We don't want to store the pointers to the camera entities directly.
///   This class is used to add an indirection and to be able to tell if an entity was removed from the scene.
class EntityAccessor
{
public:
  inline EntityAccessor() : m_uiElementIndex(VIS_INVALID), m_sMenuName() {}
  inline EntityAccessor(VisBaseEntity_cl* pEntity, const VString& sMenuName) 
    : m_uiElementIndex(pEntity->GetNumber()) 
    , m_sMenuName(sMenuName)
  {}

  // Returns NULL if the entity does not exist.
  VisBaseEntity_cl* GetEntity() const;
  inline bool IsValid() const { return (GetEntity() != NULL); }

  inline VisBaseEntity_cl* operator->() const { return GetEntity(); }

  template <typename EntityType>
  inline EntityType* GetAs() const { return vdynamic_cast<EntityType*>(GetEntity()); }

  template <typename ComponentType>
  inline ComponentType* GetComponentOfBaseType() const 
  { 
    VisBaseEntity_cl* pEntity = GetEntity();
    if (pEntity == NULL)
      return NULL;
    return pEntity->Components().GetComponentOfBaseType<ComponentType>();
  }

  inline const VString GetMenuName() const { return m_sMenuName; }

private:
  unsigned int m_uiElementIndex;
  VString m_sMenuName;
};

/// \brief
///   Module for activating individual camera objects placed in the scene.
///
/// The module adds all cameras in the scene to the VAppMenu.
///
/// \ingroup VisionAppFramework
class VCameraHandling : public VAppModule
{
  V_DECLARE_DYNCREATE(VCameraHandling);

public:
  VCameraHandling();
  virtual ~VCameraHandling() {}

  virtual void Init() HKV_OVERRIDE;
  virtual void DeInit() HKV_OVERRIDE;

  virtual void OnHandleCallback(IVisCallbackDataObject_cl* pData) HKV_OVERRIDE;

private:
  void BuildCameraList();
  void ReleaseCameraList();

  void InitFreeCamera();
  void DeInitFreeCamera();
  void PlaceFreeCameraAtCurrentPosition();

  void ActivateCameraByActionIndex(int iIndex);
  bool ActivateCamera(const EntityAccessor& entity);
  void DeactivateAllCameras();

  void SetWASDControlsEnabled(bool bEnabled);

  // Store indices in entity element manager.
  VMap<int, EntityAccessor> m_actionMap; ///< Map action index to camera entity.

  VSmartPtr<VFreeCamera> m_spFreeCamera;
  bool m_bWASDEnabled;
  int m_iWASDActionIndex;

  const VString m_sMenuGroupName;
};

#endif // __V_CAMERA_HANDLING_HPP

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
