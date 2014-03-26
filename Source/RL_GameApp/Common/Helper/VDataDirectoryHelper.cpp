/*
 *
 * Confidential Information of Telekinesys Research Limited (t/a Havok). Not for disclosure or distribution without Havok's
 * prior written consent. This software contains code, techniques and know-how which is confidential and proprietary to Havok.
 * Product and Trade Secret source code contains trade secrets of Havok. Havok Software (C) Copyright 1999-2013 Telekinesys Research Limited t/a Havok. All Rights Reserved. Use of this software is subject to the terms of an end user license agreement.
 *
 */


#include <Vision/Runtime/Framework/VisionApp/Helper/VDataDirectoryHelper.hpp>
#include <Vision/Runtime/Base/System/VManifest.hpp>

void VDataDirectoryHelper::SelectAssetProfile(const char* szScene, bool bAllowFallbackProfile)
{
  if (!bAllowFallbackProfile || (szScene == NULL) || !AssetProfile::IsProfileNameSet())
  {
    return;
  }

  // Find the data directory of a scene file with the base name of the scene to open. It doesn't matter whether
  // that file is for a profile we're interested in - we just need it to find out the correct data directory.
  char szSceneBaseName[FS_MAX_PATH];
  VPathHelper::GetFilenameNoExt(szSceneBaseName, szScene);

  VString sSearchPath;
  for (int i = -1; i < TARGETDEVICE_COUNT; ++i)
  {
    VString sSceneFileName;
    sSceneFileName.Format("%s%s%s.vscene", szSceneBaseName,
      i >= 0 ? "." : "",
      i >= 0 ? VTargetDeviceName[i] : "");

    VScopedFileStream<IVFileInStream> fileStream(Vision::File.Open(sSceneFileName));
    if (fileStream == NULL)
    {
      continue;
    }

    sSearchPath = fileStream->GetInitialSearchPath();

    if (!sSearchPath.IsEmpty())
    {
      break;
    }
  }

  // If we couldn't find out the data directory, give up.
  if (sSearchPath.IsEmpty())
  {
    return;
  }

  // If we support the asset profile we intend to open, no further action is required.
  if (VFileAccessManager::GetInstance()->IsAssetProfileSupported(AssetProfile::GetProfileName(), sSearchPath))
  {
    return;
  }

  // Are we on a platform that can fall back to DX9? If yes, try to do so.
  if ((VStringHelper::SafeCompare(AssetProfile::GetProfileName(), VTargetDeviceName[TARGETDEVICE_DX11]) == 0) ||
    (VStringHelper::SafeCompare(AssetProfile::GetProfileName(), VTargetDeviceName[TARGETDEVICE_PS3]) == 0) ||
    (VStringHelper::SafeCompare(AssetProfile::GetProfileName(), VTargetDeviceName[TARGETDEVICE_XBOX360]) == 0) ||
    (VStringHelper::SafeCompare(AssetProfile::GetProfileName(), VTargetDeviceName[TARGETDEVICE_PSP2]) == 0) ||
    (VStringHelper::SafeCompare(AssetProfile::GetProfileName(), VTargetDeviceName[TARGETDEVICE_WIIU]) == 0))
  {
    if (VFileAccessManager::GetInstance()->IsAssetProfileSupported(VTargetDeviceName[TARGETDEVICE_DX9], sSearchPath))
    {
      Vision::File.SetAssetProfile(VTargetDeviceName[TARGETDEVICE_DX9]);
      return;
    }
  }

  // Tizen may fall back to Android
  if ((VStringHelper::SafeCompare(AssetProfile::GetProfileName(), VTargetDeviceName[TARGETDEVICE_TIZEN]) == 0))
  {
    if (VFileAccessManager::GetInstance()->IsAssetProfileSupported(VTargetDeviceName[TARGETDEVICE_ANDROID], sSearchPath))
    {
      printf("Falling back to Android profile!");

      // Set the corresponding variant keys for Android first...
      const int numVariantKeys = AssetVariantKeys::GetCount();
      for (int i = 0; i < numVariantKeys; ++i)
      {
        if (VStringHelper::SafeCompare(AssetVariantKeys::Get(i), "Tizen-Default") == 0)
        {
          AssetVariantKeys::Add("Android-Default");
        }
        else if (VStringHelper::SafeCompare(AssetVariantKeys::Get(i), "Tizen-PVR") == 0)
        {
          AssetVariantKeys::Add("Android-PVR");
        }
      }

      // ...then switch the profile over.
      Vision::File.SetAssetProfile(VTargetDeviceName[TARGETDEVICE_ANDROID]);
      return;
    }
  }

  // if this is any other platform, just stick with the default profile, even though we did not find any aidlt file
}

void VDataDirectoryHelper::ProcessManifestFile(bool bAddDataDirs, bool bLoadEnginePlugins)
{
  VFileAccessManager::NativePathResult manifestNativeResult;
  if (VFileAccessManager::GetInstance()->MakePathNative("vForgeManifest.txt", manifestNativeResult, VFileSystemAccessMode::READ, VFileSystemElementType::FILE) != HKV_SUCCESS)
    return;

  char szProjectDir[FS_MAX_PATH];
  VFileHelper::GetFileDir(manifestNativeResult.m_sNativePath, szProjectDir);

  VManifest manifest;
  if(manifest.LoadManifest(manifestNativeResult.m_sNativePath))
  {
    int iNumEntries;
    VManifest::VManifestEntry* pEntries;
    manifest.GetEntries(iNumEntries, pEntries);

    for(int iEntryIdx = 0; iEntryIdx < iNumEntries; iEntryIdx++)
    {
      VManifest::VManifestEntry& entry = pEntries[iEntryIdx];
      if (bAddDataDirs && (entry.m_command == "AddDataDir"))
      {
        static int iNextRootNo = 0;
        char rootName[VFileAccessManager::MAX_ROOT_NAME_LENGTH];
        char dataDir[FS_MAX_PATH];
        if (VFileAccessManager::IsPathRelative(entry.m_value))
        {
          VFileHelper::CombineDirAndDir(dataDir, szProjectDir, entry.m_value);
        }
        else
        {
          strcpy(dataDir, entry.m_value.AsChar());
        }
        
        if (VFileAccessManager::IsPathNative(dataDir))
        {
          VFileAccessManager::AbsolutePathResult outputAbsResult;
          if (VFileAccessManager::GetInstance()->MakePathAbsolute(dataDir, outputAbsResult, VFileSystemAccessMode::READ, VFileSystemElementType::DIRECTORY) == HKV_SUCCESS)
          {
            Vision::File.AddSearchPath(outputAbsResult.m_sAbsolutePath);
          }
          else
          {
            vis_snprintf(rootName, VFileAccessManager::MAX_ROOT_NAME_LENGTH, "manifest_dir_%i", iNextRootNo++);
            Vision::File.AddFileSystem(rootName, dataDir, VFileSystemFlags::ADD_SEARCH_PATH);
          }
        }
        else if (VFileAccessManager::IsPathAbsolute(dataDir))
        {
          Vision::File.AddSearchPath(dataDir, VSearchPathFlags::PATH_MUST_EXIST);
        }
      }
      else if (bLoadEnginePlugins && (entry.m_command == "LoadEnginePlugin"))
      {
        bool pluginLoaded = Vision::Plugins.IsEnginePluginLoaded(entry.m_value) 
          || Vision::Plugins.GetRegisteredPlugin(entry.m_value.AsChar())
          || Vision::Plugins.LoadEnginePlugin(entry.m_value);

        if (!pluginLoaded)
        {
          hkvLog::Warning("Engine plugin '%s' referenced in vForgeManifest.txt file failed to load", entry.m_value.AsChar());
        }
      }
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
