/*
 *
 * Confidential Information of Telekinesys Research Limited (t/a Havok). Not for disclosure or distribution without Havok's
 * prior written consent. This software contains code, techniques and know-how which is confidential and proprietary to Havok.
 * Product and Trade Secret source code contains trade secrets of Havok. Havok Software (C) Copyright 1999-2013 Telekinesys Research Limited t/a Havok. All Rights Reserved. Use of this software is subject to the terms of an end user license agreement.
 *
 */

#ifndef __V_CHECK_OUTPUT_FOLDER_STARTUP_MODULE_HPP
#define __V_CHECK_OUTPUT_FOLDER_STARTUP_MODULE_HPP

#include <Vision/Runtime/Base/VBase.hpp>
#include <Vision/Runtime/Base/Container/VScopedPtr.hpp>
#include <Vision/Runtime/Base/System/Dialog/VNativeDialog.hpp>
#include <Vision/Runtime/Framework/VisionApp/VAppModule.hpp>

class IVNativeDialog;

/// \brief
///   Application Start-up module to check accessibility of the output folder on 
///   Android/Tizen devices.
///
/// This module checks that the output directory (usually the device's internal memory)
/// is actually accessible. If the device is connected to a PC as USB mass storage device,
/// attempts to access the output folders are blocked by the operating system and thus
/// always fail.
///
/// If this start-up module is registered with the application, the output folder is checked
/// at start-up time and a message box describing the problem is shown in case the output
/// folder is not accessible. This message box offers choices to either continue starting the
/// application or to exit gracefully.
///
/// On platforms other than Android and Tizen, this module does nothing.
class VCheckOutputFolderStartupModule : public VStartupModule
{
public:
  virtual bool Run() HKV_OVERRIDE;

private:
  VScopedPtr<IVNativeDialog> m_spDialog;
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
