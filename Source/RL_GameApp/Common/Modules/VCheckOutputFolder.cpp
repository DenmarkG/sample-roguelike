/*
 *
 * Confidential Information of Telekinesys Research Limited (t/a Havok). Not for disclosure or distribution without Havok's
 * prior written consent. This software contains code, techniques and know-how which is confidential and proprietary to Havok.
 * Product and Trade Secret source code contains trade secrets of Havok. Havok Software (C) Copyright 1999-2013 Telekinesys Research Limited t/a Havok. All Rights Reserved. Use of this software is subject to the terms of an end user license agreement.
 *
 */

#include <Vision/Runtime/Framework/VisionApp/Modules/VCheckOutputFolder.hpp>

#include <Vision/Runtime/Framework/VisionApp/VAppBase.hpp>

#if defined(_VISION_ANDROID) || defined(_VISION_TIZEN)
  #include <dirent.h>
#endif

bool VCheckOutputFolderStartupModule::Run()
{
  // Check if we're currently waiting for a dialog.
  if (m_spDialog != NULL)
  {
    switch (m_spDialog->GetState())
    {
    case IVNativeDialog::WAITING:
      Sleep(100);
      return true;

    case IVNativeDialog::BUTTON1:
      VAppBase::Get()->Quit();
      // fall-through

    default:
#if defined(_VISION_ANDROID)
      VVideo::GetVideoConfig()->bRunWhileSleeping = false;
#endif
      return false;
    }
  }

#if defined(_VISION_ANDROID) || defined(_VISION_TIZEN)
  DIR* dir = opendir(VAppBase::Get()->GetPlatformStorageDirectory());
  if (dir != NULL)
  {
    // We can access the output dir. This doesn't actually say anything about the writability, but
    // it catches the case we need to catch, when the system blocks all access to internal storage
    // due to it being connected in UMS mode.
    closedir(dir);
    return false;
  }

  // Failed to stat the output directory. Display a warning and optionally quit.
  m_spDialog = IVNativeDialog::CreateInstance();
  m_spDialog->SetTitle("Storage Problem");
  m_spDialog->SetText("Unable to write to internal storage. Check that the device is not connected in UMS mode.");
  m_spDialog->AddButton("Continue");
  m_spDialog->AddButton("Quit");
  m_spDialog->Show();

#if defined(_VISION_ANDROID)
  // Allow running the app while the file serve dialog is shown in the foreground
  VVideo::GetVideoConfig()->bRunWhileSleeping = true;
#endif

  return true;
#else
  return false;
#endif
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
