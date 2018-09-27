#include "RenderPipelineMTL.h"
#include "DeviceMTL.h"
#include "ShaderModuleMTL.h"

CC_BACKEND_BEGIN

namespace
{
    MTLVertexStepFunction toMTLVertexStepFunction(VertexStepMode vertexStepMode)
    {
        if (VertexStepMode::VERTEX == vertexStepMode)
            return MTLVertexStepFunctionPerVertex;
        else
            return MTLVertexStepFunctionPerInstance;
    }
    
    MTLVertexFormat toMTLVertexFormat(VertexFormat vertexFormat)
    {
        MTLVertexFormat ret = MTLVertexFormatFloat4;
        switch (vertexFormat)
        {
            case VertexFormat::FLOAT_R32G32B32A32:
                ret = MTLVertexFormatFloat4;
                break;
            case VertexFormat::FLOAT_R32G32B32:
                ret = MTLVertexFormatFloat3;
                break;
            case VertexFormat::FLOAT_R32G32:
                ret = MTLVertexFormatFloat2;
                break;
            case VertexFormat::FLOAT_R32:
                ret = MTLVertexFormatFloat;
                break;
            case VertexFormat::INT_R32G32B32A32:
                ret = MTLVertexFormatInt4;
                break;
            case VertexFormat::INT_R32G32B32:
                ret = MTLVertexFormatInt3;
                break;
            case VertexFormat::INT_R32G32:
                ret = MTLVertexFormatInt2;
                break;
            case VertexFormat::INT_R32:
                ret = MTLVertexFormatInt;
                break;
            case VertexFormat::USHORT_R16G16B16A16:
                ret = MTLVertexFormatUShort4;
                break;
            case VertexFormat::USHORT_R16G16:
                ret = MTLVertexFormatUShort2;
                break;
            case VertexFormat::UNORM_R8G8B8A8:
                ret = MTLVertexFormatUChar4;
                break;
            case VertexFormat::UNORM_R8G8:
                ret = MTLVertexFormatUChar2;
                break;
            default:
                assert("unknow format");
                break;
        }
        return ret;
    }
}

RenderPipelineMTL::RenderPipelineMTL(id<MTLDevice> mtlDevice, const RenderPipelineDescriptor& descriptor)
{
    MTLRenderPipelineDescriptor *mtlDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
    mtlDescriptor.colorAttachments[0].pixelFormat = DeviceMTL::getCAMetalLayer().pixelFormat;
    mtlDescriptor.vertexFunction = static_cast<ShaderModuleMTL*>(descriptor.getVertexShaderModule())->getMTLFunction();
    mtlDescriptor.fragmentFunction = static_cast<ShaderModuleMTL*>(descriptor.getFragmentShaderModule())->getMTLFunction();
    
    const auto& vertexLayouts = descriptor.getVertexLayouts();
    int vertexIndex = 0;
    for (const auto& vertexLayout : vertexLayouts)
    {
        if (!vertexLayout.isValid())
            continue;
        
        mtlDescriptor.vertexDescriptor.layouts[vertexIndex].stride = vertexLayout.getStride();
        mtlDescriptor.vertexDescriptor.layouts[vertexIndex].stepFunction = toMTLVertexStepFunction(vertexLayout.getVertexStepMode());
        
        const auto& attributes = vertexLayout.getAttributes();
        for (const auto& attribute : attributes)
        {
            mtlDescriptor.vertexDescriptor.attributes[attribute.index].format = toMTLVertexFormat(attribute.format);
            mtlDescriptor.vertexDescriptor.attributes[attribute.index].offset = attribute.offset;
            // Buffer index will always be 0;
            mtlDescriptor.vertexDescriptor.attributes[attribute.index].bufferIndex = 0;
        }
        
        ++vertexIndex;
    }
    
    _mtlRenderPipelineState = [mtlDevice newRenderPipelineStateWithDescriptor:mtlDescriptor error:nil];
    
    [mtlDescriptor release];
}

CC_BACKEND_END