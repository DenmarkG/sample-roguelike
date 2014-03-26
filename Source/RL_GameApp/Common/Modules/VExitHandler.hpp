/*
 *
 * Confidential Information of Telekinesys Research Limited (t/a Havok). Not for disclosure or distribution without Havok's
 * prior written consent. This software contains code, techniques and know-how which is confidential and proprietary to Havok.
 * Product and Trade Secret source code contains trade secrets of Havok. Havok Software (C) Copyright 1999-2013 Telekinesys Research Limited t/a Havok. All Rights Reserved. Use of this software is subject to the terms of an end user license agreement.
 *
 */

#ifndef __V_EXIT_HANDLER
#define __V_EXIT_HANDLER

#include <Vision/Runtime/Engine/System/Vision.hpp>
#include <Vision/Runtime/Framework/VisionApp/VAppModule.hpp>

#include <Vision/Runtime/EnginePlugins/VisionEnginePlugin/GUI/VMenuIncludes.hpp>

/// \brief
///   This class provides a simple exit dialog functionality.
class VExitDialog : public VDialog
{
public:
  VExitDialog();

  virtual void OnItemClicked(VMenuEventDataObject* pEvent) HKV_OVERRIDE;

  inline bool IsExitTriggered() const { return m_bExitTriggered; }
  void CloseDialog();

  inline void SetUnlockInput(bool bValue) { m_bUnlockInput = bValue; }

protected:
  V_DECLARE_SERIAL_DLLEXP(VExitDialog, DECLSPEC_DLLEXPORT);
  VOVERRIDE void Serialize(VArchive &ar) {}

private:
  bool m_bExitTriggered;

  VTextLabel* m_pLabel;

  VStyledButton* m_pCancelButton;
  VStyledButton* m_pExitButton;

  bool m_bUnlockInput;
};

/// \brief
///   The Exit Handler is responsible for closing the application.
///
/// The Exit Handler also features to show an exit dialog which prompts the user
/// whether to close the application or not.
///
/// \ingroup VisionAppFramework
class VExitHandler : public VAppModule
{
  V_DECLARE_DYNCREATE(VExitHandler);

public:
	VExitHandler();
	virtual ~VExitHandler() {}

  virtual void Init() HKV_OVERRIDE;
  virtual void DeInit() HKV_OVERRIDE;

  virtual void OnHandleCallback(IVisCallbackDataObject_cl* pData) HKV_OVERRIDE;
  virtual int GetCallbackSortingKey(VCallback *pCallback) HKV_OVERRIDE { return 1; }

  /// \brief
  ///   Sets the flag if the Exit Handler should show an exit dialog or not.
  virtual inline void SetShowExitDialog(bool bShow) { m_bShowExitDialog = bShow; }

  /// \brief
  ///   Returns the flag if the Exit Handler is currently configured to show an exit dialog or not.
  virtual inline bool IsExitDialogShown() const { return m_bShowExitDialog; }

  /// \brief
  ///   Returns whether the exit dialog is currently visible or not.
  virtual inline bool IsExitDialogVisible() const { return m_spExitDlg->IsVisible(); }

protected:
  VSmartPtr<VExitDialog> m_spExitDlg;

  bool m_bShowExitDialog;
};

#endif //__V_EXIT_HANDLER

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
