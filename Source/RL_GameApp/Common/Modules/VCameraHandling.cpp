/*
 *
 * Confidential Information of Telekinesys Research Limited (t/a Havok). Not for disclosure or distribution without Havok's
 * prior written consent. This software contains code, techniques and know-how which is confidential and proprietary to Havok.
 * Product and Trade Secret source code contains trade secrets of Havok. Havok Software (C) Copyright 1999-2013 Telekinesys Research Limited t/a Havok. All Rights Reserved. Use of this software is subject to the terms of an end user license agreement.
 *
 */

#include <Vision/Runtime/Framework/VisionApp/Modules/VCameraHandling.hpp>
#include <Vision/Runtime/Framework/VisionApp/VAppImpl.hpp>

#include <Vision/Runtime/EnginePlugins/VisionEnginePlugin/Entities/PathCameraEntity.hpp>
#include <Vision/Runtime/EnginePlugins/VisionEnginePlugin/Entities/CameraPositionEntity.hpp>
#include <Vision/Runtime/EnginePlugins/VisionEnginePlugin/Components/VOrbitCamera.hpp>
#include <Vision/Runtime/EnginePlugins/VisionEnginePlugin/Input/VVirtualThumbStick.hpp>

//-----------------------------------------------------------------------------------

VisBaseEntity_cl* EntityAccessor::GetEntity() const
{
  if (VisBaseEntity_cl::ElementManagerGetSize() <= m_uiElementIndex)
    return NULL;

  return VisBaseEntity_cl::ElementManagerGetAt(m_uiElementIndex);
}

//-----------------------------------------------------------------------------------

V_IMPLEMENT_DYNCREATE(VCameraHandling, VAppModule, Vision::GetEngineModule());

VCameraHandling::VCameraHandling()
  : m_actionMap()
  , m_spFreeCamera(NULL)
  , m_bWASDEnabled(true)
  , m_iWASDActionIndex(-1)
  , m_sMenuGroupName("Cameras")
{
}

void VCameraHandling::Init()
{
  Vision::Callbacks.OnAfterSceneLoaded += this;
  Vision::Callbacks.OnBeforeSceneUnloaded += this;
}

void VCameraHandling::DeInit()
{
  Vision::Callbacks.OnAfterSceneLoaded -= this;
  Vision::Callbacks.OnBeforeSceneUnloaded -= this;

  // De-initializing the camera lists must happen when the scene gets unloaded.
  VASSERT_MSG(m_actionMap.IsEmpty() && m_spFreeCamera == NULL,
    "VCameraHandling: Camera lists should have already been deinitialized at shutdown");
}

void VCameraHandling::OnHandleCallback(IVisCallbackDataObject_cl* pData)
{
  if (pData->m_pSender == &Vision::Callbacks.OnAfterSceneLoaded)
  {
    BuildCameraList();
    InitFreeCamera();
  }
  else if (pData->m_pSender == &Vision::Callbacks.OnBeforeSceneUnloaded)
  {
    DeInitFreeCamera();
    ReleaseCameraList();
  }
  else
  {
    const int iActionIndex = GetCallbackIndex(pData);
    if (iActionIndex < 0)
      return;

    if (iActionIndex == m_iWASDActionIndex)
    {
      SetWASDControlsEnabled(!m_bWASDEnabled);
    }
    else
    {
      ActivateCameraByActionIndex(iActionIndex);
    }
  }
}

//-----------------------------------------------------------------------------------

void VCameraHandling::BuildCameraList()
{
  VAppMenu* pMainMenu = GetParent()->GetAppModule<VAppMenu>();
  if (pMainMenu == NULL)
    return;

  int iActionIndex = 0;
  VAppMenuItems menuItems;
  menuItems.Add(VAppMenuItem("<Switch to Free Camera>", iActionIndex++, 0, false));

#if defined(WIN32) && !defined(_VISION_WINRT)
  // Add option to disable WASD controls.
  m_iWASDActionIndex = iActionIndex++;
  menuItems.Add(VAppMenuItem("<Toggle Free Camera WASD Controls>", m_iWASDActionIndex, 1, true, m_bWASDEnabled));
#endif

  // Find camera objects in the scene.
  // Only store element manager indices in order to be able to detect removed objects.
  unsigned int uiNumOrbitCameras = 0;
  unsigned int uiNumCameraPositions = 0;
  unsigned int uiNumPathCameras = 0;

  const unsigned int uiNumEntities = VisBaseEntity_cl::ElementManagerGetSize();
  for (unsigned int uiElementIndex = 0; uiElementIndex < uiNumEntities; uiElementIndex++)
  {
    VisBaseEntity_cl* pEntity = VisBaseEntity_cl::ElementManagerGet(uiElementIndex);
    if (pEntity == NULL)
      continue;

    // Try to convert the entity to all of the supported camera types.
    VOrbitCamera* pOrbitCamera = pEntity->Components().GetComponentOfBaseType<VOrbitCamera>();
    CameraPositionEntity* pCameraPosition = vdynamic_cast<CameraPositionEntity*>(pEntity);
    PathCameraEntity* pPathCamera = vdynamic_cast<PathCameraEntity*>(pEntity);

    // Menu name data 
    const char* szKey = "";
    const char* szCameraType = "";
    unsigned int uiSortingKey = 0;
    unsigned int uiCameraIndex = 0;

    if (pOrbitCamera != NULL)
    {
      // If the owner entity's key is not set, use the model's file name.
      const char* szKey = pEntity->GetObjectKey();
      if (VStringUtil::IsEmpty(szKey))
        szKey = (pEntity->GetMesh() ? pEntity->GetMesh()->GetFilename() : "");

      szCameraType = "OrbitCamera";
      uiSortingKey = 2;
      uiCameraIndex = uiNumOrbitCameras++;
    }
    else if (pCameraPosition != NULL)
    {
      szKey = pEntity->GetObjectKey();
      szCameraType = "CameraPosition";
      uiSortingKey = 3;
      uiCameraIndex = uiNumCameraPositions++;
    }
    else if (pPathCamera != NULL)
    {
      szKey = pEntity->GetObjectKey();
      szCameraType = "PathCamera";
      uiSortingKey = 4;
      uiCameraIndex = uiNumPathCameras++;
    }
    else
    {
      // If we haven't found a free camera entity yet, try to store this one.
      if (m_spFreeCamera == NULL)
        m_spFreeCamera = vdynamic_cast<VFreeCamera*>(pEntity);

      // No camera found.
      continue;
    }

    // Generate menu name.
    VString sMenuName;
    if (VStringUtil::IsEmpty(szKey))
      sMenuName.Format("%s%02d", szCameraType, uiCameraIndex + 1);
    else
      sMenuName.Format("%s%02d (%s)", szCameraType, uiCameraIndex + 1, szKey);

    menuItems.Add(VAppMenuItem(sMenuName, iActionIndex, uiSortingKey, false));
    m_actionMap.SetAt(iActionIndex++, EntityAccessor(pEntity, sMenuName));
  }

  m_callbacks.Append(pMainMenu->RegisterGroup(m_sMenuGroupName, menuItems, NULL, VAPP_DEFAULT_SORTING_2 + 1));
  RegisterCallbacks();
}

void VCameraHandling::ReleaseCameraList()
{
  DeactivateAllCameras();

  DeRegisterCallbacks();

  VAppMenu* pMainMenu = GetParent()->GetAppModule<VAppMenu>();
  if (pMainMenu != NULL)
    pMainMenu->RemoveGroup(m_sMenuGroupName);

  m_callbacks.RemoveAll();

  m_actionMap.RemoveAll();

  m_iWASDActionIndex = -1;
}

//-----------------------------------------------------------------------------------

void VCameraHandling::InitFreeCamera()
{
  // Store free camera that was found in the scene.
  VFreeCamera* pFreeCameraInScene = m_spFreeCamera;

  // Create own free camera.
  // Do not call InitFunction yet. We want to disable the ThinkFunctionStatus first.
  VisEntityTemplate_cl initTemplate;
  initTemplate.m_pszClassName = "VFreeCamera";
  initTemplate.m_bCallInitFunction = false;
  m_spFreeCamera = vstatic_cast<VFreeCamera*>(Vision::Game.CreateEntity(initTemplate));

  m_spFreeCamera->SetThinkFunctionStatus(FALSE);
  m_spFreeCamera->SetObjectFlag(VObjectFlag_AutoDispose);
  m_spFreeCamera->InitFunction(); // Call InitFunction only now.

  // Apply WASD setting to all free cameras.
  SetWASDControlsEnabled(m_bWASDEnabled);

  // Check if there are orbit or path cameras.
  bool bHasOrbitOrPathCamera = false;

  for (VPOSITION it = m_actionMap.GetStartPosition(); it != NULL;)
  {
    int iActionIndex;
    EntityAccessor entity;
    m_actionMap.GetNextPair(it, iActionIndex, entity);

    VASSERT(entity.IsValid());
    if (entity.GetComponentOfBaseType<VOrbitCamera>() != NULL || 
      entity.GetAs<PathCameraEntity>() != NULL)
    {
      bHasOrbitOrPathCamera = true;
      break;
    }
  }

  // Fall back to default camera transformation if there are no active cameras.
  if (!bHasOrbitOrPathCamera && pFreeCameraInScene == NULL)
  {
    DeactivateAllCameras();

    m_spFreeCamera->SetPosition(GetParent()->GetSceneLoader().m_vDefaultCamPos);
    m_spFreeCamera->SetRotationMatrix(GetParent()->GetSceneLoader().m_DefaultCamRot);

    m_spFreeCamera->SetThinkFunctionStatus(TRUE);
  }
}

void VCameraHandling::DeInitFreeCamera()
{
  if (Vision::Camera.GetMainCamera()->GetParent() == m_spFreeCamera)
    Vision::Camera.AttachToEntity(NULL, hkvVec3::ZeroVector());

  m_spFreeCamera = NULL;
}

void VCameraHandling::PlaceFreeCameraAtCurrentPosition()
{
  hkvVec3 vPos;
  hkvMat3 mRot;
  Vision::Camera.GetCurrentCameraPosition(vPos);
  Vision::Camera.GetCurrentCameraRotation(mRot);

  m_spFreeCamera->SetPosition(vPos);
  m_spFreeCamera->SetRotationMatrix(mRot);

  // Re-attach main camera to free camera.
  Vision::Camera.AttachToEntity(m_spFreeCamera, hkvVec3::ZeroVector());

  m_spFreeCamera->SetThinkFunctionStatus(TRUE);
}

//-----------------------------------------------------------------------------------

void VCameraHandling::ActivateCameraByActionIndex(int iActionIndex)
{
  EntityAccessor entity;
  if (!m_actionMap.Lookup(iActionIndex, entity))
  {
    // Activate the free camera for the current position.
    DeactivateAllCameras();
    PlaceFreeCameraAtCurrentPosition();
    return;
  }
    
  if (!ActivateCamera(entity))
  {
    // Remove item from menu since it doesn't exist anymore.
    VAppMenu* pMainMenu = GetParent()->GetAppModule<VAppMenu>();
    if (pMainMenu != NULL)
      pMainMenu->RemoveItem(entity.GetMenuName());

    m_actionMap.RemoveKey(iActionIndex);

    Vision::Message.Add("Camera object has been removed from the scene.\n");
  }
}

//-----------------------------------------------------------------------------------

bool VCameraHandling::ActivateCamera(const EntityAccessor& entity)
{
  if (!entity.IsValid())
    return false;

  // Always deactivate all cameras in case a camera was made active by code / script.
  DeactivateAllCameras();

  CameraPositionEntity* pCameraPosition = entity.GetAs<CameraPositionEntity>();
  if (pCameraPosition != NULL)
  {
    // Apply FOV, and near / far plane settings. Afterwards the main camera is 
    // attached to the camera position.
    pCameraPosition->ApplyToContext(Vision::Contexts.GetMainRenderContext());

    // Copy transformation to free camera.
    PlaceFreeCameraAtCurrentPosition();
    return true;
  }

  VOrbitCamera* pOrbitCamera = entity.GetComponentOfBaseType<VOrbitCamera>();
  if (pOrbitCamera != NULL)
  {
    pOrbitCamera->SetEnabled(true);
    return true;
  }

  PathCameraEntity* pPathCamera = entity.GetAs<PathCameraEntity>();
  if (pPathCamera != NULL)
  {
    pPathCamera->Start();
    return true;
  }

  return false;
}

void VCameraHandling::DeactivateAllCameras()
{
  // Deactivate all orbit and path cameras.
  const unsigned int uiNumEntities = VisBaseEntity_cl::ElementManagerGetSize();

  for (unsigned int uiElementIndex = 0; uiElementIndex < uiNumEntities; uiElementIndex++)
  {
    VisBaseEntity_cl* pEntity = VisBaseEntity_cl::ElementManagerGet(uiElementIndex);
    if (pEntity == NULL)
      continue;

    VFreeCamera* pFreeCamera = vdynamic_cast<VFreeCamera*>(pEntity);
    VOrbitCamera* pOrbitCamera = pEntity->Components().GetComponentOfBaseType<VOrbitCamera>();
    PathCameraEntity* pPathCamera = vdynamic_cast<PathCameraEntity*>(pEntity);

    if (pFreeCamera != NULL)
      pFreeCamera->SetThinkFunctionStatus(FALSE);

    if (pOrbitCamera != NULL)
      pOrbitCamera->SetEnabled(false);

    if (pPathCamera != NULL)
      pPathCamera->Stop();
  }
}

void VCameraHandling::SetWASDControlsEnabled(bool bEnabled)
{
#if defined(WIN32) && !defined(VISION_WINRT)
  const unsigned int uiNumEntities = VisBaseEntity_cl::ElementManagerGetSize();
  for (unsigned int uiElementIndex = 0; uiElementIndex < uiNumEntities; uiElementIndex++)
  {
    VisBaseEntity_cl* pEntity = VisBaseEntity_cl::ElementManagerGet(uiElementIndex);
    VFreeCamera* pFreeCamera = vdynamic_cast<VFreeCamera*>(pEntity);
    if (pFreeCamera != NULL)
      pFreeCamera->SetWASDControlsEnabled(bEnabled);
  }
#endif

  m_bWASDEnabled = bEnabled;
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
