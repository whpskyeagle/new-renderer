#include "RenderPipelineMTL.h"
#include "DeviceMTL.h"
#include "ShaderModuleMTL.h"
#include "DepthStencilStateMTL.h"
#include "Utils.h"

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
                assert(false);
                break;
        }
        return ret;
    }
}

RenderPipelineMTL::RenderPipelineMTL(id<MTLDevice> mtlDevice, const RenderPipelineDescriptor& descriptor)
: _mtlDevice(mtlDevice)
{
    _mtlRenderPipelineDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
    
    setShaderModules(descriptor);
    setVertexLayout(_mtlRenderPipelineDescriptor, descriptor);
    
    // Depth stencil state.
    auto depthStencilState = descriptor.depthStencilState;
    if (depthStencilState)
        _mtlDepthStencilState = static_cast<DepthStencilStateMTL*>(depthStencilState)->getMTLDepthStencilState();
    
    auto blendState = static_cast<BlendStateMTL*>(descriptor.blendState);
    if (blendState)
        _blendDescriptorMTL = blendState->getBlendDescriptorMTL();
    
    setBlendStateAndFormat(descriptor);
    
    _mtlRenderPipelineState = [_mtlDevice newRenderPipelineStateWithDescriptor:_mtlRenderPipelineDescriptor error:nil];
    [_mtlRenderPipelineDescriptor release];
}

RenderPipelineMTL::~RenderPipelineMTL()
{
    [_mtlRenderPipelineState release];
}

void RenderPipelineMTL::setVertexLayout(MTLRenderPipelineDescriptor* mtlDescriptor, const RenderPipelineDescriptor& descriptor)
{
    const auto& vertexLayouts = descriptor.vertexLayouts;
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
}

void RenderPipelineMTL::setBlendState(MTLRenderPipelineColorAttachmentDescriptor* colorAttachmentDescriptor)
{
    colorAttachmentDescriptor.blendingEnabled = _blendDescriptorMTL.blendEnabled;
    colorAttachmentDescriptor.writeMask = _blendDescriptorMTL.writeMask;
    
    colorAttachmentDescriptor.rgbBlendOperation = _blendDescriptorMTL.rgbBlendOperation;
    colorAttachmentDescriptor.alphaBlendOperation = _blendDescriptorMTL.alphaBlendOperation;
    
    colorAttachmentDescriptor.sourceRGBBlendFactor = _blendDescriptorMTL.sourceRGBBlendFactor;
    colorAttachmentDescriptor.destinationRGBBlendFactor = _blendDescriptorMTL.destinationRGBBlendFactor;
    colorAttachmentDescriptor.sourceAlphaBlendFactor = _blendDescriptorMTL.sourceAlphaBlendFactor;
    colorAttachmentDescriptor.destinationAlphaBlendFactor = _blendDescriptorMTL.destinationAlphaBlendFactor;
}

void RenderPipelineMTL::setShaderModules(const RenderPipelineDescriptor& descriptor)
{
    auto vertexShaderModule = static_cast<ShaderModuleMTL*>(descriptor.vertexShaderModule);
    _mtlRenderPipelineDescriptor.vertexFunction = vertexShaderModule->getMTLFunction();
    _vertexUniforms = vertexShaderModule->getUniforms();
    _vertexUniformBuffer = vertexShaderModule->getUniformBuffer();
    _vertexTextures = vertexShaderModule->getTextures();
    
    auto fragShaderModule = static_cast<ShaderModuleMTL*>(descriptor.fragmentShaderModule);
    _mtlRenderPipelineDescriptor.fragmentFunction = fragShaderModule->getMTLFunction();
    _fragmentUniforms = fragShaderModule->getUniforms();
    _fragementUniformBuffer = fragShaderModule->getUniformBuffer();
    _fragmentTextures = fragShaderModule->getTextures();
}

void RenderPipelineMTL::setBlendStateAndFormat(const RenderPipelineDescriptor& descriptor)
{
    for (int i = 0; i < MAX_COLOR_ATTCHMENT; ++i)
    {
        if (TextureFormat::NONE == descriptor.colorAttachmentsFormat[i])
            continue;
        
        _mtlRenderPipelineDescriptor.colorAttachments[i].pixelFormat = Utils::toMTLPixelFormat(descriptor.colorAttachmentsFormat[i]);
        setBlendState(_mtlRenderPipelineDescriptor.colorAttachments[i]);
    }
    _mtlRenderPipelineDescriptor.depthAttachmentPixelFormat = Utils::toMTLPixelFormat(descriptor.depthAttachmentFormat);
    _mtlRenderPipelineDescriptor.stencilAttachmentPixelFormat = Utils::toMTLPixelFormat(descriptor.stencilAttachmentFormat);
}

CC_BACKEND_END
