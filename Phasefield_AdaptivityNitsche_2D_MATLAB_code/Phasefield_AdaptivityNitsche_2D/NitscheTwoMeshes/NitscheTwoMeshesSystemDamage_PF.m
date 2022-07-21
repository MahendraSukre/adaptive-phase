function [K,f] = NitscheTwoMeshesSystemDamage_PF(X,T,Xref,Tref,refinedElements,referenceElementStd,referenceElementRef,NitscheFaces,H,Gc,l,beta)

nOfElements = size(T,1);
nOfNitscheFaces = size(NitscheFaces,1);
nOfFaceNodes = size(referenceElementStd.NodesCoord1d,1);
faceNodes = referenceElementStd.faceNodes;
nIPstd = length(referenceElementStd.IPweights);
nIPref = length(referenceElementRef.IPweights);

standardElements = setdiff(1:nOfElements,refinedElements);

nDOF = size(X,1)+size(Xref,1);
f = zeros(nDOF,1);

%[mKe,mKe] = size(Ke)
mKe = size(referenceElementStd.NodesCoord,1); nStdEls = length(standardElements);
ind_i_std  = zeros(mKe*mKe,nStdEls); 
ind_j_std  = zeros(mKe*mKe,nStdEls); 
coefK_std = zeros(mKe*mKe,nStdEls); 

% Volume integrals 
for i = 1:length(standardElements)
    iElem = standardElements(i);
    Gc_elem = Gc(iElem); l_elem = l(iElem);
    Te = T(iElem,:); Xe = X(Te,:);
    Hg = H((i-1)*nIPstd + (1:nIPstd));
    [Ke,fe] = computeVolumeMatrices(Xe,referenceElementStd,Gc_elem,l_elem,Hg);
    ind = Te;
    f(ind) = f(ind) + fe;
    [mi,mj] = meshgrid(ind,ind);
    ind_i_std(:,i) = mi(:); ind_j_std(:,i) = mj(:);
    coefK_std(:,i) = Ke(:);
end

mKe = size(referenceElementRef.NodesCoord,1); nRefEls = length(refinedElements);
ind_i_ref  = zeros(mKe*mKe,nRefEls); 
ind_j_ref  = zeros(mKe*mKe,nRefEls); 
coef_K_ref = zeros(mKe*mKe,nRefEls); 

for i = 1:length(refinedElements)
    iElem = refinedElements(i);
    Gc_elem = Gc(iElem); l_elem = l(iElem);
    Te = Tref(i,:); Xe = Xref(Te,:);
    Hg = H(nIPstd*length(standardElements) + (i-1)*nIPref + (1:nIPref));
    [Ke,fe] = computeVolumeMatrices(Xe,referenceElementRef,Gc_elem,l_elem,Hg);
    ind = Te + size(X,1);
    f(ind) = f(ind) + fe;
    [mi,mj] = meshgrid(ind,ind);
    ind_i_ref(:,i) = mi(:); ind_j_ref(:,i) = mj(:);
    coef_K_ref(:,i) = Ke(:);
end

K = sparse([ind_i_std(:);ind_i_ref(:)],[ind_j_std(:);ind_j_ref(:)],[coefK_std(:);coef_K_ref(:)]);

%Integrals on INTERIOR faces (loop in faces)
%Calculo com si refinat per les dues bandes + projeccio a l'espai std on
%toqui
N2dfaces=referenceElementRef.NfacesIP; N2dxifaces=referenceElementRef.NxifacesIP; N2detafaces=referenceElementRef.NetafacesIP;
N2dxiGeofaces = referenceElementRef.NxiGeofacesIP;
N2detaGeofaces = referenceElementRef.NetaGeofacesIP;
N1dxiGeo = referenceElementRef.N1dxiGeo;
IPw_f = referenceElementRef.IPweights1d; ngf = length(IPw_f);
for iFace=1:nOfNitscheFaces
    %% Info de la cara
    infoiFace = NitscheFaces(iFace,:);
    refElem = infoiFace(2); refFaceNum = infoiFace(3);
    stdElem = infoiFace(4); stdFaceNum = infoiFace(5);
    
    %% Funcions aprox
    refN2d = N2dfaces{refFaceNum}; 
    stdN2d = N2dfaces{stdFaceNum}; stdN2d = stdN2d(end:-1:1,:);
    refN2dxi = N2dxifaces{refFaceNum}; 
    stdN2dxi = N2dxifaces{stdFaceNum}; stdN2dxi = stdN2dxi(end:-1:1,:);
    refN2deta = N2detafaces{refFaceNum}; 
    stdN2deta = N2detafaces{stdFaceNum}; stdN2deta = stdN2deta(end:-1:1,:);
    
    %% Funcions geo
    refN2dxiGeo = N2dxiGeofaces{refFaceNum};
    stdN2dxiGeo = N2dxiGeofaces{stdFaceNum}; stdN2dxiGeo = stdN2dxiGeo(end:-1:1,:);
    refN2detaGeo = N2detaGeofaces{refFaceNum};
    stdN2detaGeo = N2detaGeofaces{stdFaceNum}; stdN2detaGeo = stdN2detaGeo(end:-1:1,:);
    
    %% Std element derivatives
    iElem = stdElem;
    Nxi = stdN2dxi; Neta = stdN2deta;
    NxiGeo = stdN2dxiGeo; NetaGeo = stdN2detaGeo;
    Te = T(iElem,:); Xe = X(Te,:); Testd = Te;
    J11 = NxiGeo*Xe(:,1); J12 = NxiGeo*Xe(:,2);
    J21 = NetaGeo*Xe(:,1); J22 = NetaGeo*Xe(:,2);
    detJ = J11.*J22-J12.*J21;
    invJ11 = spdiags(J22./detJ,0,ngf,ngf); invJ12 = spdiags(-J12./detJ,0,ngf,ngf);
    invJ21 = spdiags(-J21./detJ,0,ngf,ngf); invJ22 = spdiags(J11./detJ,0,ngf,ngf);
    stdN2dx = invJ11*Nxi + invJ12*Neta;    stdN2dy = invJ21*Nxi + invJ22*Neta;
    %% Ref element derivatives
    iElem = refElem; equivRef = find(refinedElements==iElem);
    Nxi = refN2dxi; Neta = refN2deta;
    NxiGeo = refN2dxiGeo; NetaGeo = refN2detaGeo;
    Te = T(iElem,:); Xe = X(Te,:);
    Teref = Tref(equivRef,:) + size(X,1);
    J11 = NxiGeo*Xe(:,1); J12 = NxiGeo*Xe(:,2); J21 = NetaGeo*Xe(:,1); J22 = NetaGeo*Xe(:,2); detJ = J11.*J22-J12.*J21;
    invJ11 = spdiags(J22./detJ,0,ngf,ngf); invJ12 = spdiags(-J12./detJ,0,ngf,ngf);
    invJ21 = spdiags(-J21./detJ,0,ngf,ngf); invJ22 = spdiags(J11./detJ,0,ngf,ngf);
    refN2dx = invJ11*Nxi + invJ12*Neta;    refN2dy = invJ21*Nxi + invJ22*Neta;
    %Elemental matrices
    muL = Gc(refElem)*l(refElem); muR = Gc(stdElem)*l(stdElem);
    %% Integrals on the face (as seen from ref element)
    nodes = faceNodes(refFaceNum,:); Xf = X(T(refElem,nodes),:); % Nodes in the face
    dxdxi = N1dxiGeo*Xf(:,1); dydxi = N1dxiGeo*Xf(:,2);
    dxdxiNorm = sqrt(dxdxi.^2+dydxi.^2);
    dline = dxdxiNorm.*IPw_f;
    nx = dydxi./dxdxiNorm; ny=-dxdxi./dxdxiNorm; %normal exterior to the left element
    Ddline = spdiags(dline,0,ngf,ngf); Ddline_nx = spdiags(dline.*nx,0,ngf,ngf); Ddline_ny = spdiags(dline.*ny,0,ngf,ngf);
    ref_dline_n_muGradN=muL*(Ddline_nx*refN2dx+Ddline_ny*refN2dy);
    std_dline_n_muGradN=muR*(Ddline_nx*stdN2dx+Ddline_ny*stdN2dy);
    KeLL=-0.5*refN2d'*ref_dline_n_muGradN ...
        -0.5*ref_dline_n_muGradN'*refN2d ...
        +beta*refN2d'*(Ddline*refN2d);
    KeRR=0.5*stdN2d'*std_dline_n_muGradN ...
        +0.5*std_dline_n_muGradN'*stdN2d ...
        +beta*stdN2d'*(Ddline*stdN2d);
    KeLR=-0.5*refN2d'*std_dline_n_muGradN ...
        +0.5*ref_dline_n_muGradN'*stdN2d ...
        -beta*refN2d'*(Ddline*stdN2d);    
    %% Reduccio matrius (right = std)
    P = referenceElementRef.P2d;
    KeRR = P*KeRR*P';
    KeLR = KeLR*P';
    
    %% Ensamblatge
    K(Teref,Teref)=K(Teref,Teref)+KeLL;
    K(Teref,Testd)=K(Teref,Testd)+KeLR;
    K(Testd,Teref)=K(Testd,Teref)+KeLR';
    K(Testd,Testd)=K(Testd,Testd)+KeRR;
end

function [Ke,fe] = computeVolumeMatrices(Xe,referenceElement,Gc,l,Hg)
N = referenceElement.N; Nxi = referenceElement.Nxi; Neta = referenceElement.Neta;
IPw = referenceElement.IPweights; ngauss = length(IPw);
J11 = Nxi*Xe(:,1); J12 = Nxi*Xe(:,2); J21 = Neta*Xe(:,1); J22 = Neta*Xe(:,2);
detJ = J11.*J22-J12.*J21;
%maybe we should use bsxfun instead of diagonal matrices...
dvolu = referenceElement.IPweights.*detJ;
dvolu_d = spdiags(dvolu,0,ngauss,ngauss);
invJ11 = spdiags(J22./detJ,0,ngauss,ngauss); invJ12 = spdiags(-J12./detJ,0,ngauss,ngauss);
invJ21 = spdiags(-J21./detJ,0,ngauss,ngauss); invJ22 = spdiags(J11./detJ,0,ngauss,ngauss);
Nx = invJ11*Nxi + invJ12*Neta;    Ny = invJ21*Nxi + invJ22*Neta;

fe = 2*N'*(dvolu_d*Hg);
Ke = Gc*l*(Nx'*(dvolu_d*Nx)+Ny'*(dvolu_d*Ny)) + N'*(spdiags(dvolu.*(Gc/l+2*Hg),0,ngauss,ngauss)*N);
