/*
 *
 * Confidential Information of Telekinesys Research Limited (t/a Havok). Not for disclosure or distribution without Havok's
 * prior written consent. This software contains code, techniques and know-how which is confidential and proprietary to Havok.
 * Product and Trade Secret source code contains trade secrets of Havok. Havok Software (C) Copyright 1999-2013 Telekinesys Research Limited t/a Havok. All Rights Reserved. Use of this software is subject to the terms of an end user license agreement.
 *
 */

#ifndef __V_SCREEN_SHOT_HELPER
#define __V_SCREEN_SHOT_HELPER

#include <Vision/Runtime/Engine/System/Vision.hpp>

/// \brief
///   Helper class used to save a screenshot to file.
///
/// \ingroup VisionAppFramework
class VScreenShotHelper : public VRefCounter
{
public:
  VScreenShotHelper();
  ~VScreenShotHelper();

  /// \brief
  ///   Capture current framebuffer content.
  ///
  /// Note: This function should be called within Vision's OnBeforeSwapBuffers callback.
  void Capture();

  /// \brief
  ///   Returns if there is pending data that could be saved.
  inline bool PendingDataInBuffer() { return m_pTmpBuffer!=NULL; };

  /// \brief
  ///   Save the previously captured framebuffer content to file.
  ///
  /// \param szCacheDirectory
  ///   Directory where the image should be saved.
  ///
  /// \param szFileName
  ///   Image filename.
  ///
  /// \param fBrightness
  ///   Brightness value used for color correction.
  ///
  /// \param fSaturation
  ///   Saturation value used for color correction.
  bool SaveBufferToFile(const char* szCacheDirectory, const char* szFileName, float fBrightness, float fSaturation);

  /// \brief
  ///   Returns the path to the last screen shot that was saved.
  inline const char* GetScreenShotPath() const { return m_sScreenShotPath; }

protected:
  unsigned char *m_pTmpBuffer;

  VString m_sTmpFileName;
  VString m_sScreenShotPath;
  
  int m_iCaptureResX;
  int m_iCaptureResY;
};

#endif //__V_SCREEN_SHOT_HELPER

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
