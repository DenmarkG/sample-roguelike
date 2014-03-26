/*
 *
 * Confidential Information of Telekinesys Research Limited (t/a Havok). Not for disclosure or distribution without Havok's
 * prior written consent. This software contains code, techniques and know-how which is confidential and proprietary to Havok.
 * Product and Trade Secret source code contains trade secrets of Havok. Havok Software (C) Copyright 1999-2013 Telekinesys Research Limited t/a Havok. All Rights Reserved. Use of this software is subject to the terms of an end user license agreement.
 *
 */

#ifndef __V_LOGO_OVERLAY
#define __V_LOGO_OVERLAY

#include <Vision/Runtime/Engine/System/Vision.hpp>
#include <Vision/Runtime/Framework/VisionApp/VAppModule.hpp>

/// \brief
///   Module showing an overlay logo/icon on top of the scene.
///
/// \ingroup VisionAppFramework
class VLogoOverlay : public VAppModule
{
  V_DECLARE_DYNCREATE(VLogoOverlay);

public:
  enum Alignment
  {
    ALIGN_TOPLEFT = 0,
    ALIGN_TOPRIGHT,
    ALIGN_BOTTOMLEFT,
    ALIGN_BOTTOMRIGHT,
    ALIGN_TOP,
    ALIGN_BOTTOM
  };

	VLogoOverlay(Alignment eAlignment = ALIGN_BOTTOMRIGHT) : VAppModule(), m_eAlignment(eAlignment) {}
	virtual ~VLogoOverlay() {}

  virtual void Init() HKV_OVERRIDE;
  virtual void DeInit() HKV_OVERRIDE;

  virtual void OnHandleCallback(IVisCallbackDataObject_cl* pData) HKV_OVERRIDE;

  void SetAlignment(Alignment eAlignment);
  inline Alignment GetAlignment() const { return m_eAlignment; }

protected:
  virtual void RefreshLayout();
  const VRectanglef GetScreenExtents() const;

  VisScreenMaskPtr m_spLogoOverlay;
  Alignment m_eAlignment;
};

#endif //__V_LOGO_OVERLAY

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
