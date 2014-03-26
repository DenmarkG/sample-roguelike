/*
 *
 * Confidential Information of Telekinesys Research Limited (t/a Havok). Not for disclosure or distribution without Havok's
 * prior written consent. This software contains code, techniques and know-how which is confidential and proprietary to Havok.
 * Product and Trade Secret source code contains trade secrets of Havok. Havok Software (C) Copyright 1999-2013 Telekinesys Research Limited t/a Havok. All Rights Reserved. Use of this software is subject to the terms of an end user license agreement.
 *
 */

#ifndef __V_FILESERVE_STARTUP_MODULE_HPP
#define __V_FILESERVE_STARTUP_MODULE_HPP

#include <Vision/Runtime/Base/System/IO/FileSystems/VFileServeDaemon.hpp>

/// \brief A startup module that presents the user an option dialog in order to establish a vFileServe connection.
class VFileServeStartupModule : public VStartupModule
{
  /// \brief Starts the FileServeDaemon.
  virtual void Init() HKV_OVERRIDE
  {
#if defined(_VISION_IOS)
    // On iOS, the cache directory may be cleared by the OS. In order to be able to reliably load scenes from cache, use the persistent storage instead.
    VString cachePath = VPathHelper::CombineDirAndDir(VAppBase::Get()->GetApplicationDataDirectory(), "FileServeCache");
#else
    VString cachePath = VPathHelper::CombineDirAndDir(VAppBase::Get()->GetPlatformCacheDirectory(), "FileServeCache");
#endif
    VString settingsFile = VPathHelper::CombineDirAndDir(VAppBase::Get()->GetPlatformStorageDirectory(), "vFileServeHost.txt");
    VFileServeDaemon::Init(settingsFile, cachePath);
  }

  /// \brief Runs the FileServeDaemon until a connection was made or the user chose to exit or use the cache.
  virtual bool Run() HKV_OVERRIDE
  {
    switch(VFileServeDaemon::GetInstance()->RunSetup())
    {
    case VFileServeDaemon::SR_NOT_DONE_YET:
      return true;

    case VFileServeDaemon::SR_FINISHED:
      return false;

    case VFileServeDaemon::SR_FAILED:
      VAppBase::Get()->Quit();
      return false;
    }
  }
};

#endif

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
