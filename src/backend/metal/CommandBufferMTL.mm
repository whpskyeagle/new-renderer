#include "CommandBufferMTL.h"
#include "BufferMTL.h"
#include "RenderPassMTL.h"
#include "DeviceMTL.h"
#include "RenderPipelineMTL.h"
#include "TextureMTL.h"
#include "Utils.h"
#include "../BindGroup.h"

CC_BACKEND_BEGIN

namespace
{
    MTLPrimitiveType toMTLPrimitive(PrimitiveType primitiveType)
    {
        MTLPrimitiveType ret = MTLPrimitiveTypeTriangle;
        switch (primitiveType)
        {
            case PrimitiveType::POINT:
                ret = MTLPrimitiveTypePoint;
                break;
            case PrimitiveType::LINE:
                ret = MTLPrimitiveTypeLine;
                break;
            case PrimitiveType::LINE_STRIP:
                ret = MTLPrimitiveTypeLineStrip;
                break;
            case PrimitiveType::TRIANGLE:
                ret = MTLPrimitiveTypeTriangle;
                break;
            case PrimitiveType::TRIANGLE_STRIP:
                ret = MTLPrimitiveTypeTriangleStrip;
                break;
            default:
                break;
        }
        return ret;
    }
    
    MTLIndexType toMTLIndexType(IndexFormat indexFormat)
    {
        if (IndexFormat::U_SHORT == indexFormat)
            return MTLIndexTypeUInt16;
        else
            return MTLIndexTypeUInt32;
    }
}

CommandBufferMTL::CommandBufferMTL(DeviceMTL* deviceMTL)
: _mtlCommandQueue([deviceMTL->getMTLDevice() newCommandQueue])
, _deviceMTL(deviceMTL)
{
}

CommandBufferMTL::~CommandBufferMTL()
{
    [_mtlCommandQueue release];
}

void CommandBufferMTL::beginRenderPass(RenderPass* renderPass)
{
    _mtlCommandBuffer = [_mtlCommandQueue commandBuffer];
    [_mtlCommandBuffer retain];
    
    if (renderPass)
        _mtlRenderEncoder = [_mtlCommandBuffer renderCommandEncoderWithDescriptor:static_cast<RenderPassMTL*>(renderPass)->getMTLRenderPassDescriptor()];
    else
        _mtlRenderEncoder = [_mtlCommandBuffer renderCommandEncoderWithDescriptor:Utils::getDefaultRenderPassDescriptor()];
    
    [_mtlRenderEncoder retain];
    [_mtlRenderEncoder setFrontFacingWinding:MTLWindingCounterClockwise];
    
    _renderPass = renderPass;
}

void CommandBufferMTL::setRenderPipeline(RenderPipeline* renderPipeline)
{
    CC_SAFE_RETAIN(renderPipeline);
    CC_SAFE_RELEASE(_renderPipelineMTL);
    _renderPipelineMTL = static_cast<RenderPipelineMTL*>(renderPipeline);
    _renderPipelineMTL->apply(_renderPass);
}

void CommandBufferMTL::setViewport(uint32_t x, uint32_t y, uint32_t w, uint32_t h)
{
    MTLViewport viewport;
    viewport.originX = x;
    viewport.originY = y;
    viewport.width = w;
    viewport.height = h;
    viewport.znear = -1;
    viewport.zfar = 1;
    [_mtlRenderEncoder setViewport:viewport];
}

void CommandBufferMTL::setVertexBuffer(uint32_t index, Buffer* buffer)
{
    [_mtlRenderEncoder setVertexBuffer:static_cast<BufferMTL*>(buffer)->getMTLBuffer()
                                offset:0
                               atIndex:index];
}

void CommandBufferMTL::setBindGroup(BindGroup* bindGroup)
{
    CC_SAFE_RETAIN(bindGroup);
    CC_SAFE_RELEASE(_bindGroup);
    _bindGroup = bindGroup;
}

void CommandBufferMTL::setIndexBuffer(Buffer* buffer)
{
    assert(buffer != nullptr);
    if (!buffer)
        return;
    
    _mtlIndexBuffer = static_cast<BufferMTL*>(buffer)->getMTLBuffer();
    [_mtlIndexBuffer retain];
}

void CommandBufferMTL::drawArrays(PrimitiveType primitiveType, uint32_t start,  uint32_t count)
{
    prepareDrawing();
    [_mtlRenderEncoder drawPrimitives:toMTLPrimitive(primitiveType)
                          vertexStart:start
                          vertexCount:count];
    afterDraw();
}

void CommandBufferMTL::drawElements(PrimitiveType primitiveType, IndexFormat indexType, uint32_t count)
{
    prepareDrawing();
    [_mtlRenderEncoder drawIndexedPrimitives:toMTLPrimitive(primitiveType)
                                  indexCount:count
                                   indexType:toMTLIndexType(indexType)
                                 indexBuffer:_mtlIndexBuffer
                           indexBufferOffset:0];
    afterDraw();
}

void CommandBufferMTL::endRenderPass()
{
    [_mtlRenderEncoder endEncoding];
    [_mtlCommandBuffer presentDrawable:DeviceMTL::getCurrentDrawable()];
    [_mtlCommandBuffer commit];
    
    [_mtlCommandBuffer release];
    [_mtlRenderEncoder release];
}

void CommandBufferMTL::afterDraw()
{
    if (_mtlIndexBuffer)
    {
        [_mtlIndexBuffer release];
        _mtlIndexBuffer = nullptr;
    }
    
    CC_SAFE_RELEASE_NULL(_bindGroup);
}

void CommandBufferMTL::prepareDrawing() const
{
    setUniformBuffer();
    setTextures();
    
    auto mtlDepthStencilState = _renderPipelineMTL->getMTLDepthStencilState();
    if (mtlDepthStencilState)
        [_mtlRenderEncoder setDepthStencilState:mtlDepthStencilState];
    
    [_mtlRenderEncoder setRenderPipelineState:_renderPipelineMTL->getMTLRenderPipelineState()];
}

void CommandBufferMTL::setTextures() const
{
    if (_bindGroup)
    {
        doSetTextures(_renderPipelineMTL->getVertexTextures(), true);
        doSetTextures(_renderPipelineMTL->getFragmentTextures(), false);
    }
}

void CommandBufferMTL::doSetTextures(const std::vector<std::string>& textures, bool isVertex) const
{
    const auto& bindTextureInfos = _bindGroup->getTextureInfos();
    int i = 0;
    for (const auto& texture : textures)
    {
        auto iter = bindTextureInfos.find(texture);
        if (bindTextureInfos.end() != iter)
        {
            //FIXME: should support texture array.
            const auto& textures = iter->second.textures;
            const auto& mtlTexture = static_cast<TextureMTL*>(textures[0]);
            
            if (isVertex)
            {
                [_mtlRenderEncoder setVertexTexture:mtlTexture->getMTLTexture()
                                            atIndex:i];
                [_mtlRenderEncoder setVertexSamplerState:mtlTexture->getMTLSamplerState()
                                                 atIndex:i];
            }
            else
            {
                [_mtlRenderEncoder setFragmentTexture:mtlTexture->getMTLTexture()
                                              atIndex:i];
                [_mtlRenderEncoder setFragmentSamplerState:mtlTexture->getMTLSamplerState()
                                                   atIndex:i];
            }
            
            ++i;
        }
    }
}

void CommandBufferMTL::setUniformBuffer() const
{
    if (_bindGroup)
    {
        // Uniform buffer is bound to index 1.
        const auto& vertexUniformBuffer = _renderPipelineMTL->getVertexUniformBuffer();
        if (vertexUniformBuffer)
        {
            uint32_t size = fillUniformBuffer(vertexUniformBuffer, _renderPipelineMTL->getVertexUniforms());
            [_mtlRenderEncoder setVertexBytes:vertexUniformBuffer
                                       length:size atIndex:1];
        }
        
        const auto& fragUniformBuffer = _renderPipelineMTL->getFragmentUniformBuffer();
        if (fragUniformBuffer)
        {
            uint32_t size = fillUniformBuffer(fragUniformBuffer, _renderPipelineMTL->getFragmentUniforms());
            [_mtlRenderEncoder setFragmentBytes:fragUniformBuffer
                                         length:size
                                        atIndex:1];
        }
    }
}

uint32_t CommandBufferMTL::fillUniformBuffer(void* buffer, const std::vector<std::string>& uniforms) const
{
    const auto& bindUniformInfos = _bindGroup->getUniformInfos();
    uint32_t offset = 0;
    for (const auto& uniform : uniforms)
    {
        auto iter = bindUniformInfos.find(uniform);
        if (bindUniformInfos.end() != iter)
        {
            const auto& bindUniformInfo = iter->second;
            memcpy((char*)buffer + offset, bindUniformInfo.data, bindUniformInfo.size);
            offset += bindUniformInfo.size;
        }
    }
    return offset;
}

CC_BACKEND_END
