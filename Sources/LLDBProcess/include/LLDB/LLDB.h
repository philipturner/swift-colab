//===-- LLDB.h --------------------------------------------------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef LLDB_API_LLDB_H
#define LLDB_API_LLDB_H

#include <LLDB/SBAddress.h>
#include <LLDB/SBAttachInfo.h>
#include <LLDB/SBBlock.h>
#include <LLDB/SBBreakpoint.h>
#include <LLDB/SBBreakpointLocation.h>
#include <LLDB/SBBreakpointName.h>
#include <LLDB/SBBroadcaster.h>
#include <LLDB/SBCommandInterpreter.h>
#include <LLDB/SBCommandInterpreterRunOptions.h>
#include <LLDB/SBCommandReturnObject.h>
#include <LLDB/SBCommunication.h>
#include <LLDB/SBCompileUnit.h>
#include <LLDB/SBData.h>
#include <LLDB/SBDebugger.h>
#include <LLDB/SBDeclaration.h>
#include <LLDB/SBDefines.h>
#include <LLDB/SBEnvironment.h>
#include <LLDB/SBError.h>
#include <LLDB/SBEvent.h>
#include <LLDB/SBExecutionContext.h>
#include <LLDB/SBExpressionOptions.h>
#include <LLDB/SBFile.h>
#include <LLDB/SBFileSpec.h>
#include <LLDB/SBFileSpecList.h>
#include <LLDB/SBFrame.h>
#include <LLDB/SBFunction.h>
#include <LLDB/SBHostOS.h>
#include <LLDB/SBInstruction.h>
#include <LLDB/SBInstructionList.h>
#include <LLDB/SBLanguageRuntime.h>
#include <LLDB/SBLaunchInfo.h>
#include <LLDB/SBLineEntry.h>
#include <LLDB/SBListener.h>
#include <LLDB/SBMemoryRegionInfo.h>
#include <LLDB/SBMemoryRegionInfoList.h>
#include <LLDB/SBModule.h>
#include <LLDB/SBModuleSpec.h>
#include <LLDB/SBPlatform.h>
#include <LLDB/SBProcess.h>
#include <LLDB/SBProcessInfo.h>
#include <LLDB/SBQueue.h>
#include <LLDB/SBQueueItem.h>
#include <LLDB/SBReproducer.h>
#include <LLDB/SBSection.h>
#include <LLDB/SBSourceManager.h>
#include <LLDB/SBStream.h>
#include <LLDB/SBStringList.h>
#include <LLDB/SBStructuredData.h>
#include <LLDB/SBSymbol.h>
#include <LLDB/SBSymbolContext.h>
#include <LLDB/SBSymbolContextList.h>
#include <LLDB/SBTarget.h>
#include <LLDB/SBThread.h>
#include <LLDB/SBThreadCollection.h>
#include <LLDB/SBThreadPlan.h>
#include <LLDB/SBTrace.h>
#include <LLDB/SBTraceOptions.h>
#include <LLDB/SBType.h>
#include <LLDB/SBTypeCategory.h>
#include <LLDB/SBTypeEnumMember.h>
#include <LLDB/SBTypeFilter.h>
#include <LLDB/SBTypeFormat.h>
#include <LLDB/SBTypeNameSpecifier.h>
#include <LLDB/SBTypeSummary.h>
#include <LLDB/SBTypeSynthetic.h>
#include <LLDB/SBUnixSignals.h>
#include <LLDB/SBValue.h>
#include <LLDB/SBValueList.h>
#include <LLDB/SBVariablesOptions.h>
#include <LLDB/SBWatchpoint.h>

#endif // LLDB_API_LLDB_H
