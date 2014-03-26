/*
 *
 * Confidential Information of Telekinesys Research Limited (t/a Havok). Not for disclosure or distribution without Havok's
 * prior written consent. This software contains code, techniques and know-how which is confidential and proprietary to Havok.
 * Product and Trade Secret source code contains trade secrets of Havok. Havok Software (C) Copyright 1999-2013 Telekinesys Research Limited t/a Havok. All Rights Reserved. Use of this software is subject to the terms of an end user license agreement.
 *
 */

#ifndef __V_RESTORE_SCREEN
#define __V_RESTORE_SCREEN

#include <Vision/Runtime/Engine/System/Vision.hpp>
#include <Vision/Runtime/Framework/VisionApp/Modules/VLoadingScreen.hpp>

/// \brief
///   Restore Screen used when application restores from background.
///
/// Basically the Restore Screen is a simple Loading Screen, and for that purpose
/// uses the functionality from VLoadingScreen. Additionally to that the Restore
/// Screen also takes care about leaving the foreground (on mobile platforms).
/// In that case the Restore Screen automatically captures an image of the
/// framebuffer which is used as the Restore Screen's background texture.
///
/// \ingroup VisionAppFramework
class VRestoreScreen : public VLoadingScreenBase
{
  V_DECLARE_DYNCREATE(VRestoreScreen);

public:
  VRestoreScreen();

  /// \brief
  ///   Non-Default Constructor.
  ///
  /// \param fBrightness
  ///   Brightness of the background texture.
  ///
  /// \param fSaturation
  ///   Saturation of the background texture.
	VRestoreScreen(float fBrightness, float fSaturation);

	virtual ~VRestoreScreen() {}

  virtual void Init() HKV_OVERRIDE;
  virtual void DeInit() HKV_OVERRIDE;

  virtual void OnHandleCallback(IVisCallbackDataObject_cl* pData) HKV_OVERRIDE;

protected:
  /// \brief
  ///   Writes the screen to a memory buffer.
  void GrabBackgroundScreenshot();

  /// \brief
  ///   Saves the screenshot, previously grabbed by GraphBackgroundScreenshot(), to the disk and applies the color correction.
  void SaveBackgroundScreenshot();

  /// \brief
  ///   Override default background texture.
  virtual VTextureObject* CreateBackgroundImage() HKV_OVERRIDE;

  /// \brief
  ///   Applies the given brightness and saturation to the given buffer.
  static void ColorCorrect(unsigned char* pBuffer, int iWidth, int iHeight, float fBrightness, float fSaturation);

private:
  bool m_bGrab;
  unsigned char* m_pScreenshotBuffer;

  float m_fBrightness;
  float m_fSaturation;
};

#endif //__V_RESTORE_SCREEN

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
