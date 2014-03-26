/*
 *
 * Confidential Information of Telekinesys Research Limited (t/a Havok). Not for disclosure or distribution without Havok's
 * prior written consent. This software contains code, techniques and know-how which is confidential and proprietary to Havok.
 * Product and Trade Secret source code contains trade secrets of Havok. Havok Software (C) Copyright 1999-2013 Telekinesys Research Limited t/a Havok. All Rights Reserved. Use of this software is subject to the terms of an end user license agreement.
 *
 */

#include <Vision/Runtime/Framework/VisionApp/Helper/VScreenShotHelper.hpp>

VScreenShotHelper::VScreenShotHelper()
  : m_pTmpBuffer(NULL)
  , m_sTmpFileName("_screenshot.bmp")
  , m_sScreenShotPath()
  , m_iCaptureResX(0)
  , m_iCaptureResY(0)
{
}

VScreenShotHelper::~VScreenShotHelper()
{
  V_SAFE_DELETE_ARRAY(m_pTmpBuffer);
}

void VScreenShotHelper::Capture()
{
  V_SAFE_DELETE_ARRAY(m_pTmpBuffer);

  m_iCaptureResX = Vision::Video.GetXRes();
  m_iCaptureResY = Vision::Video.GetYRes();

  m_pTmpBuffer = new unsigned char[m_iCaptureResX*m_iCaptureResY*3];

  // write the screen buffer to memory buffer
  if (!Vision::Game.WriteScreenToBuffer(0, 0, m_iCaptureResX, m_iCaptureResY, (UBYTE*)m_pTmpBuffer))
  {
    V_SAFE_DELETE_ARRAY(m_pTmpBuffer);
  }
}

bool VScreenShotHelper::SaveBufferToFile(const char* szCacheDirectory, const char* szFileName, float fBrightness, float fSaturation)
{
  if (m_pTmpBuffer == NULL)
    return false; // no screen shot available to process

  // Color correction
  float fLumFactors[3] = { 0.3f * fBrightness, 0.59f * fBrightness, 0.11f * fBrightness };
  const float fInvSaturation = 1.0f - fSaturation;
  for (int y=0; y<m_iCaptureResY; ++y)
  {
    unsigned char *pRow = &m_pTmpBuffer[y*m_iCaptureResX*3];
    for (int x=0; x<m_iCaptureResX ; ++x, pRow += 3)
    {
      unsigned char tmp[3] = { pRow[0], pRow[1], pRow[2] };

      const float fLum = static_cast<float>(pRow[0]) * fLumFactors[0] + static_cast<float>(pRow[1]) * fLumFactors[1] + static_cast<float>(pRow[2]) * fLumFactors[2];

      float fInvSaturationProduct = fInvSaturation * fLum;
      pRow[0] = hkvMath::Min(255, static_cast<unsigned char>(fSaturation * static_cast<float>(tmp[0]) + fInvSaturationProduct));
      pRow[1] = hkvMath::Min(255, static_cast<unsigned char>(fSaturation * static_cast<float>(tmp[1]) + fInvSaturationProduct));
      pRow[2] = hkvMath::Min(255, static_cast<unsigned char>(fSaturation * static_cast<float>(tmp[2]) + fInvSaturationProduct));
    }
  }

  // use VTEX to scale and save the image
  Image_cl image;
  ImageMap_cl colorMap(m_iCaptureResX, m_iCaptureResY, 24, static_cast<UBYTE*>(m_pTmpBuffer));
  image.AddColorMap(colorMap);

  // build screen shot path
  m_sScreenShotPath = szCacheDirectory;
  if (szFileName != NULL)
    m_sScreenShotPath += szFileName;
  else
    m_sScreenShotPath += m_sTmpFileName;

  IVFileOutStream* pOutputStream = Vision::File.Create(m_sScreenShotPath.AsChar());
  
  if (pOutputStream==NULL)
    return false;

  RETVAL returnValue = image.SaveBMP(pOutputStream);

  if (pOutputStream)
    pOutputStream->Close();
  
  V_SAFE_DELETE_ARRAY(m_pTmpBuffer);

  return (returnValue == VERR_NOERROR);
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
