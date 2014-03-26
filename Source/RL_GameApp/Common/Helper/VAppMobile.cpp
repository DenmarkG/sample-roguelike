/*
 *
 * Confidential Information of Telekinesys Research Limited (t/a Havok). Not for disclosure or distribution without Havok's
 * prior written consent. This software contains code, techniques and know-how which is confidential and proprietary to Havok.
 * Product and Trade Secret source code contains trade secrets of Havok. Havok Software (C) Copyright 1999-2013 Telekinesys Research Limited t/a Havok. All Rights Reserved. Use of this software is subject to the terms of an end user license agreement.
 *
 */

#include <Vision/Runtime/Framework/VisionApp/Helper/VAppMobile.hpp>
#include <Vision/Runtime/Framework/VisionApp/VAppImpl.hpp>

VAppMobile::VAppMobile()
  : VAppBase()
{
  Vision::Callbacks.OnEnterBackground   += this;
  Vision::Callbacks.OnBackgroundRestore += this;
  Vision::Callbacks.OnEnterForeground   += this;
  Vision::Callbacks.OnVideoInitialized  += this;
}

VAppMobile::~VAppMobile()
{
  Vision::Callbacks.OnEnterBackground   -= this;
  Vision::Callbacks.OnBackgroundRestore -= this;
  Vision::Callbacks.OnEnterForeground   -= this;
  Vision::Callbacks.OnVideoInitialized  -= this;
}

void VAppMobile::PlatformInitSettings()
{
  VAppBase::PlatformInitSettings();

  VASSERT(m_pAppImpl != NULL);
  VAppMenuContextPtr pContext = m_pAppImpl->GetContext();
  pContext->SetShowCursor(false);
  pContext->SetSelectionOnClickOnly(true);
  pContext->SetSmoothScroll(true);
  pContext->SetSwipeToScroll(true);
}

void VAppMobile::SetupPlatformRootFileSystem()
{
  VAppBase::SetupPlatformRootFileSystem();
  Vision::File.AddFileSystem("app_cache", GetPlatformCacheDirectory(), VFileSystemFlags::WRITABLE);
}

void VAppMobile::OnHandleCallback(IVisCallbackDataObject_cl* pData)
{
  if (pData->m_pSender == &Vision::Callbacks.OnEnterBackground)
  {
    // Disable calling the run function
    SetAppState(VAppHelper::AS_SUSPENDED);
  }
  else if (pData->m_pSender == &Vision::Callbacks.OnBackgroundRestore)
  {
    SetAppState(VAppHelper::AS_SCENE_LOADING);

    VisBackgroundRestoreObject_cl* pProgressData = static_cast<VisBackgroundRestoreObject_cl*>(pData);
    if (m_pResourceRestorer == NULL) // restoring has started
    {
      m_pResourceRestorer = pProgressData->m_pBackgroundResourceRestorer;
      TriggerLoadSceneStatus(VIS_API_LOADSCENESTATUS_START, pProgressData->m_percentage, VisProgressDataObject_cl::PDOT_BACKGROUND_RESTORE);
    }

    // Update progress bar
    TriggerLoadSceneStatus(VIS_API_LOADSCENESTATUS_PROGRESS, pProgressData->m_percentage, VisProgressDataObject_cl::PDOT_BACKGROUND_RESTORE);
  }
  else if (pData->m_pSender == &Vision::Callbacks.OnEnterForeground)
  {
    // Re-set loading screen settings (only if restoration has finished)
    if (m_pResourceRestorer != NULL)
    {
      // End restoring.
      TriggerLoadSceneStatus(VIS_API_LOADSCENESTATUS_FINISHED, 100.0f, VisProgressDataObject_cl::PDOT_BACKGROUND_RESTORE);

      SetAppState(m_pAppImpl->GetSceneLoader().IsFinished() ? VAppHelper::AS_RUNNING : VAppHelper::AS_SCENE_LOADING);
      m_pResourceRestorer = NULL; // not needed anymore
    }
  }
  else if (pData->m_pSender == &Vision::Callbacks.OnVideoInitialized)
  {
    VAppMenuContextPtr pContext = m_pAppImpl->GetContext();
    // 96 DPI is our default (see Vision::Video.GetDeviceDpi())
    pContext->SetDragThreshold(Vision::Video.GetDeviceDpi() / 96.0f * 2.0f);
  }

  VAppBase::OnHandleCallback(pData);
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
