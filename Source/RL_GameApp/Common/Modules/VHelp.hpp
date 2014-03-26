/*
 *
 * Confidential Information of Telekinesys Research Limited (t/a Havok). Not for disclosure or distribution without Havok's
 * prior written consent. This software contains code, techniques and know-how which is confidential and proprietary to Havok.
 * Product and Trade Secret source code contains trade secrets of Havok. Havok Software (C) Copyright 1999-2013 Telekinesys Research Limited t/a Havok. All Rights Reserved. Use of this software is subject to the terms of an end user license agreement.
 *
 */

#ifndef __V_HELP
#define __V_HELP

#include <Vision/Runtime/Engine/System/Vision.hpp>
#include <Vision/Runtime/Framework/VisionApp/VAppModule.hpp>

/// \brief
///   Module for displaying application specific help text.
///
/// \ingroup VisionAppFramework
class VHelp : public VAppModule
{
  V_DECLARE_DYNCREATE(VHelp);

public:
  VHelp() : 
    m_bToggleEnabled(false) 
  {
  }

	VHelp(const VArray<const char*>& text) : 
    m_bToggleEnabled(false),  
    m_text(text) 
  { 
  }

	virtual ~VHelp() {}

  virtual void Init() HKV_OVERRIDE;
  virtual void DeInit() HKV_OVERRIDE;

  inline void SetText(VArray<const char*> text) { m_text = text; }

  virtual void OnHandleCallback(IVisCallbackDataObject_cl* pData) HKV_OVERRIDE;

private:
  VArray<const char*> m_text;

  bool m_bToggleEnabled;
};

#endif //__V_HELP

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
