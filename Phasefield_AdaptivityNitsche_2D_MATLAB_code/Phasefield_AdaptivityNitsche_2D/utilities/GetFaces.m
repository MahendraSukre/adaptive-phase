function [intFaces,extFaces] = GetFaces(T)
%
% [intFaces,extFaces] = GetFaces(T)
% (only for triangles and tetrahedrons)
%
% For every face i:
% intFaces(i,:)=[element1 nface1 element2 nface2 node1] for interior faces
% extFaces(i,:)=[element1 nface1] for exterior faces
%
% element1, element2:   number of the elements
% nface1, nface2:       number of face in each element
% node1:  number of node in the 2nd element that matches with the 1st node
%         in the 1st element (with the numbering of the face)
%
% Input:
% T: connectivity of the mesh
%
% Output:
% intFaces,extFaces: interior and exterior faces
%

[nElem,nen]=size(T);
nfaceel = nen;

nNodes = max(max(T));
N = zeros(nNodes,10);
nn = ones(nNodes,1);
for ielem = 1:size(T,1)
    Te = T(ielem,:);
    nn_Te = nn(Te);
    for kk = 1:nfaceel
        N(Te(kk),nn_Te(kk)) = ielem;
    end
    nn(Te) = nn(Te) +1;
end
N(:,max(nn):end) = [];

markE = zeros(nElem,nfaceel);
intFaces = zeros(fix(3/2*size(T,1)),5);
extFaces = zeros(size(T,1),2);

%Definition of the faces in the reference element
switch nen
    case 3 %triangle
        Efaces = [1 2; 2 3; 3 1];
    case 4 %tetrahedra
        Efaces = [1 2; 2 3; 3 4; 4 1];
end
intF = 1;
extF = 1;
for iElem=1:nElem
    for iFace=1:nfaceel
        if(markE(iElem,iFace)==0)
            markE(iElem,iFace)=1;
            nodesf = T(iElem,Efaces(iFace,:));

            jelem = FindElem(iElem,nodesf);

            if(jelem~=0)
                [jface,node1]=FindFace(nodesf,T(jelem,:),Efaces);
                intFaces(intF,:)=[iElem,iFace,jelem,jface,node1];
                intF = intF +1;
                markE(jelem,jface)=1;
            else
                extFaces(extF,:)=[iElem,iFace];
                extF = extF + 1;
            end
        end
    end
end

intFaces = intFaces(intFaces(:,1)~=0,:);
extFaces = extFaces(extFaces(:,1)~=0,:);

%Auxiliar functions
    function jelem = FindElem(iElem,nodesf)

        nen = length(nodesf);

        % [elems,aux] = find(T==nodesf(1));
        elems = N(nodesf(1),(N(nodesf(1),:)~=0));
        elems=elems(elems~=iElem);
        Ti=T(elems,:);
        for i=2:nen
            if(~isempty(elems))
                [aux,aux2] = find(Ti==nodesf(i));
                elems = elems(aux);
                Ti=Ti(aux,:);
            end
        end

        if(isempty(elems))
            jelem=0;
        else
            jelem=elems(1);
        end

    end

    function [jface,node1]=FindFace(nodesf,nodesE,Efaces)

        nFaces = size(Efaces,1);
        for j=1:nFaces
            nodesj = nodesE(Efaces(j,:));
            if (nodesj(1)==nodesf(1)|| nodesj(1)==nodesf(2)) && ...
                    (nodesj(2)==nodesf(1)|| nodesj(2)==nodesf(2))
                jface = j;
                node1 = find(nodesj==(nodesf(1)));
                break;
            end
        end

    end

end
