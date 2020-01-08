/** <module> utility_kb

This module models and manages the hierarchy of the KB's concepts.

@author Riccardo Zese
@license Artistic License 2.0
@copyright Riccardo Zese
*/


:- module(utility_kb, [init_hierarchy/1,create_hierarchy/1,create_hierarchy/2,get_hierarchy/3,get_hierarchy/2,update_hierarchy/1,update_hierarchy/2,print_hierarchy/0]).

:- meta_predicate init_hierarchy(:).
:- meta_predicate create_hierarchy(+).
:- meta_predicate create_hierarchy(+,+).
:- meta_predicate get_hierarchy(:,-).
:- meta_predicate get_hierarchy(+,+,-).
:- meta_predicate update_hierarchy(:).
:- meta_predicate update_hierarchy(+,+).

:- use_module(library(classes)).
:- use_module(library(ugraphs)).

%:- use_module(library(tabling)).
:- table expl_combination/4.

:- table get_combined_expls(_,_,_,_,_,_,lattice(append_expl/3)). %get_hierarchy_ric/6,
%:- table get_single_expls/7. %(_,_,_,_,_,lattice(append_expl)).

:- multifile trill:hierarchy/1.
trill:hierarchy(M:H):-
  M:kb_hierarchy(H).

clean_hierarchy(M):-
  retractall(M:kb_hierarchy(_)).

create_hierarchy(M):-
  create_hierarchy(M,true).
%  utility_kb:hierarchy_int(M).
%
%hierarchy_int(M):-
create_hierarchy(M,Stats):-%gtrace,
  (Stats=false -> true ;
     ( format("Analyzing the knowledge base...~n",[]),
       statistics(walltime,[_,_])
     )
  ),
  init_hierarchy(M:H0),%gtrace,
  %findall(C,M:class(C),L1),
  %findall(Class,M:classAssertion(Class,_Individual),L2),
  %findall(I,M:namedIndividual(I),LI1),
  %findall(Individual,M:classAssertion(_Class,Individual),LI6),
  %findall(LIS,M:sameIndividual(LIS),LI2),
  %findall(LID,M:differentIndividuals(LID),LI3),
  %append(LI2,LI4),
  %append(LI3,LI5),
  %append([LI1,LI4,LI5,LI6],LIndNS),
  %sort(LIndNS,LInd),
  %append(L1,L2,L3),
  %sort(L3,L4),
  M:kb_atom(KB),
  add_classes(H0,KB.class,H01),
  add_individuals(H01,KB.individual,H02),
  add_annotationProperties(H02,KB.annotationProperty,H03),
  add_dataProperties(H03,KB.dataProperty,H04),
  add_datatypes(H04,KB.datatype,H05),
  add_objectProperties(H05,KB.objectProperty,H1),
  retractall(M:kb_atom(_)),
  retractall(M:kb_hierarchy(_)),
  add_all_equivalentClasses(H1,M,H2),
  add_all_disjointClasses(H2,M,H3),
  add_all_disjointUnion(H3,M,H4),
  add_all_subClassOf(H4,M,H5),
  search_and_add_complex_subClassOf(H5,M,H6),
  check_disjoint(H6,H),    
  (Stats=false -> true ;
     ( statistics(walltime,[_,KBAM]),
       KBAS is KBAM / 1000,
       format("Analysis completed in ~f seconds.~n~n~n",[KBAS])
     )
  ),
  assert(M:kb_hierarchy(H)).
  %writeln(H.hierarchy),
  %writeln(H.nClasses),
  %writeln(H.disjointClasses),
  %writeln(H.classes),
  %writeln(H.explanations).

update_kb(M,add,Axiom):-
  M:kb_atom(KB),
  M:kb_hierarchy(H0),
  add_classes(H0,KB.class,H01),
  add_individuals(H01,KB.individual,H02),
  add_annotationProperties(H02,KB.annotationProperty,H03),
  add_dataProperties(H03,KB.dataProperty,H04),
  add_datatypes(H04,KB.datatype,H05),
  add_objectProperties(H05,KB.objectProperty,H1),
  retractall(M:kb_atom(_)),
  retractall(M:kb_hierarchy(_)),
  update_hierarchy_with_axiom(H1,M,Axiom,H2),
  search_and_add_complex_subClassOf(H2,M,H),
  assert(M:kb_hierarchy(H)).

update_kb(M,remove,Axiom):-
  M:kb_atom(KB),
  M:kb_hierarchy(H0),
  add_classes(H0,KB.class,H01),
  add_individuals(H01,KB.individual,H02),
  add_annotationProperties(H02,KB.annotationProperty,H03),
  add_dataProperties(H03,KB.dataProperty,H04),
  add_datatypes(H04,KB.datatype,H05),
  add_objectProperties(H05,KB.objectProperty,H1),
  retractall(M:kb_atom(_)),
  retractall(M:kb_hierarchy(_)),
  update_hierarchy_with_axiom(H1,M,Axiom,H2),
  search_and_add_complex_subClassOf(H2,M,H),
  assert(M:kb_hierarchy(H)).  

search_and_add_complex_subClassOf(H0,M,H):-
  Classes=H0.classesName,
  findall(C-D-Ex,complex_subClassOf(M,Classes,C,D,Ex),L),
  add_all_complex_subClassOf(H0,L,H).


update_hierarchy_with_axiom(M,equivalentClasses(CL)):- !,
  M:kb_hierarchy(H0),
  add_equivalentClasses(H0,CL,H),
  retractall(M:kb_hierarchy(_)),
  assert(M:kb_hierarchy(H)).

update_hierarchy_with_axiom(M,disjointClasses(CL)):- !,
  M:kb_hierarchy(H0),
  add_disjointClasses(H0,CL,H),
  retractall(M:kb_hierarchy(_)),
  assert(M:kb_hierarchy(H)).
  
update_hierarchy_with_axiom(M,disjointUnion(C,D)):- !,
  M:kb_hierarchy(H0),
  add_disjointUnion(H0,C,D,H),
  retractall(M:kb_hierarchy(_)),
  assert(M:kb_hierarchy(H)).

update_hierarchy_with_axiom(M,subClassOf(C,D)):- !,
  M:kb_hierarchy(H0),
  add_subClassOf(H0,C,D,H),
  retractall(M:kb_hierarchy(_)),
  assert(M:kb_hierarchy(H)).

update_hierarchy_with_axiom(_M,_Axiom):- !.

/*
 Initializes the hierarchy:
 - usermod: module for explanation generation 
 - hierarchy: tree with owl:Thing-
 - nClasses: number of classes
 - nIndividuals: number of individuals
 - disjointClasses: tree for disjoint classes
 - classes: dictionaty for nodes and classes
 - classesName: set of classes of the KB
 - explanations: explanations for hierarchy links
 - individuals: set of individuals of the KB
 - annotationProperties: set of annotation properties of the KB
 - dataProperties: set of data properties of the KB
 - datatypes: set of datatypes used in the KB
 - objectProperties: set of object properties of the KB
*/
% init_hierarchy(kb{hierarchy:TreeH,nClasses:1,disjointClasses:TreeD,node2classes:Classes})
init_hierarchy(M:kb{usermod:M,hierarchy:TreeH,nClasses:1,nIndividuals:0,disjointClasses:[0-'n'],classes:Classes,classesName:ClassesName,explanations:[],individuals:[],annotationProperties:[],dataProperties:[],datatypes:[],objectProperties:[]}):-
  vertices_edges_to_ugraph([0,'n'],[],TreeH),
  Classes=classes{'n':'http://www.w3.org/2002/07/owl#Nothing',0:'http://www.w3.org/2002/07/owl#Thing'},
  ClassesName=['http://www.w3.org/2002/07/owl#Nothing','http://www.w3.org/2002/07/owl#Thing'].
  %vertices_edges_to_ugraph([],[0-'n'],TreeD).

check_disjoint(KB0,KB):-
  KBH=KB0.hierarchy,
  edges(KBH,H),
  check_disjoint_int(KB0.disjointClasses,H,NewEdges),
  %collect_nodes_to_remove(NewEdges,H,[],Edges),
  %del_edges(KBH,Edges,TreeH0),
  add_edges(KBH,NewEdges,TreeH),
  KB=KB0.put(hierarchy,TreeH),!.

%=========================================================================================================

:- multifile trill:kb_info/0.
trill:kb_info:-
  utility_translation:get_module(M),
  M:hierarchy(H),
  print_hierarchy(H.hierarchy,H.classes),
  length(H.individuals,NI),
  format("~n~n=* General Info *=~n~n",[]),
  format("Classes:     ~d~n",[H.nClasses]),
  format("Individuals: ~d~n",[NI]),
  format("~n==================~n",[H.nClasses,NI]).


print_hierarchy :-
  utility_translation:get_module(M),
  M:hierarchy(H),
  print_hierarchy(H.hierarchy,H.classes).
  
  
%==========================================================================================================
% Collecting unsat classes and cleaning hier
find_n(Hier0,Hier) :-
  member(n-L,Hier0),
  find_subclass_of_n(L,[],Out,Hier0),
  delete(Hier0,n-L,Hier1),
  remove_from_hier(Out,Hier1,Hier2),
  append(Hier2,[n-Out],Hier).

remove_from_hier([],Hier,Hier).

remove_from_hier([H|T],Hier0,Hier):- 
  delete(Hier0,H-_,Hier1),
  remove_from_hier(T,Hier1,Hier).

find_subclass_of_n([],Acc,Acc,_).

find_subclass_of_n([H|T],Acc,ListOutput,Hier):- 
  member(H-L2,Hier),!,
  find_subclass_of_n(L2,Acc,ListaHelp,Hier),
  find_subclass_of_n(T,[H|ListaHelp],ListOutput,Hier).
			
find_subclass_of_n([H|T],Acc,ListOutput,Hier):- 
  find_subclass_of_n(T,[H|Acc],ListOutput,Hier).
%===========================================================================================================
% Print the hierarchy
print_hierarchy(Hier0,Classes):-
  find_n(Hier0,Hier),
  print_hierarchy(Hier,0,Classes),
  print_hierarchy(Hier,n,Classes).

print_hier_class(X):- 
  is_list(X),!,
  print_equiv_classes(X).
print_hier_class(X):- 
  write(X).

print_equiv_classes([]).
print_equiv_classes([H]):- write(H).
print_equiv_classes([H|T]):-
  write(H),write(' = '),
  print_equiv_classes(T).
  	
print_hierarchy(Hier,Class,Classes):- 
  member(Class-L,Hier),!,
  % print the class or the list of equivalent classes
  print_hier_class(Classes.get(Class)),nl,
  print_hierarchy_int(L,3,Hier,Classes).
	

print_hierarchy_int([],_,_,_).

print_hierarchy_int([HeadL|TailL],Cont,List,D):-	
  tab(Cont),
  % check whether the head is a list with print_hier_class and print it
  print_hier_class(D.get(HeadL)),nl,
  member(HeadL-L2,List),!,
  NewCont is Cont+3,
  print_hierarchy_int(L2,NewCont,List,D),
  print_hierarchy_int(TailL,Cont,List,D).

print_hierarchy_int([_|TailL],Cont,List,D):-
  print_hierarchy_int(TailL,Cont,List,D).
%===========================================================================================================
check_disjoint_int([],_,[]).

check_disjoint_int([DC1-DC2|TDisj],KBH,['n'-SameNode|NEdges0]):-
  ordered_sons(DC1,KBH,DCL1),
  ordered_sons(DC2,KBH,DCL2),
  member(SameNode,[DC1|DCL1]),
  memberchk(SameNode,[DC2|DCL2]),!,
  check_disjoint_int(TDisj,KBH,NEdges0).

check_disjoint_int([_DC1-_DC2|TDisj],KBH,NEdges):-
  check_disjoint_int(TDisj,KBH,NEdges).

ordered_sons(C,KBH,Nodes):-
  findall(X,member(C-X,KBH),Nodes0),
  findall(Y,(member(S,Nodes0),ordered_sons(S,KBH,Y)),Nodes1),
  append([Nodes0|Nodes1],Nodes).

collect_nodes_to_remove([],_H,N,N).

collect_nodes_to_remove(['n'-C|TD],H,TN0,TN):-
  findall(X-C,member(X-C,H),CN),
  append(CN,TN0,TN1),
  collect_nodes_to_remove(TD,H,TN1,TN).

add_disjoint_link(KB0,C,C1,KB):-
  Classes0=KB0.classes,
  PC=Classes0.find(C),
  PC1=Classes0.find(C1),
  ( dif(PC,PC1) -> % check KB consistency
     ( KB=KB0.put(disjointClasses,[PC-PC1|KB0.disjointClasses])
     )
    ;
     fail
  ).

add_hierarchy_link(KB0,C,C1,KB):-
  Classes0=KB0.classes,
  PC=Classes0.find(C),
  PC1=Classes0.find(C1),!,
  (dif(PC,PC1) ->
     ( add_hierarchy_link_int(KB0,PC,PC1,C,C1,KB) )
    ;
     ( add_subClass_expl(KB0.usermod,KB0.explanations,C,C1,Expls),
       KB=KB0.put(explanations,Expls)
     )
  ).

add_hierarchy_link_int(KB0,PC,PC1,C,C1,KB):-
  are_subClasses_int(KB0,PC,PC1),!, % check they are not linked yet
  merge_classes_int(KB0,PC,PC1,KB1), % merge_classes has to take into account loops between more classes: C sub D sub E, E sub C
  add_subClass_expl(KB1.usermod,KB1.explanations,C,C1,Expls),
  KB=KB1.put(explanations,Expls).

add_hierarchy_link_int(KB0,PC,PC1,C,C1,KB):- % non linkati
  del_edges(KB0.hierarchy,[0-PC],TreeH1),
  add_edges(TreeH1,[PC1-PC],TreeH),
  add_subClass_expl(KB0.usermod,KB0.explanations,C,C1,Expls),
  KB=KB0.put([hierarchy=TreeH,explanations=Expls]).


add_hierarchy_link(KB0,C,C1,Expl,KB):-
  Classes0=KB0.classes,
  PC=Classes0.find(C),
  PC1=Classes0.find(C1),!,
  (dif(PC,PC1) ->
     ( add_hierarchy_link_int(KB0,PC,PC1,C,C1,Expl,KB) )
    ;
     ( add_subClass_expl(KB0.usermod,KB0.explanations,C,C1,Expl,Expls),
       KB=KB0.put(explanations,Expls)
     )
  ).

add_hierarchy_link_int(KB0,PC,PC1,C,C1,Expl,KB):-
  are_subClasses_int(KB0,PC,PC1),!, % check they are not linked yet
  merge_classes_int(KB0,PC,PC1,KB1), % merge_classes has to take into account loops between more classes: C sub D sub E, E sub C
  add_subClass_expl(KB1.usermod,KB1.explanations,C,C1,Expl,Expls),
  KB=KB1.put(explanations,Expls).

add_hierarchy_link_int(KB0,PC,PC1,C,C1,Expl,KB):-
  del_edges(KB0.hierarchy,[0-PC],TreeH1),
  add_edges(TreeH1,[PC1-PC],TreeH),
  add_subClass_expl(KB0.usermod,KB0.explanations,C,C1,Expl,Expls),
  KB=KB0.put([hierarchy=TreeH,explanations=Expls]).


are_subClasses_int(KB,C,C1):-
  reachable(C,KB.hierarchy,L),
  %flatten(L0,L),
  memberchk(C1,L),!.


check_for_concepts_to_merge(Concept,Hier,ConceptsToMerge):-	% Given a concept C, takes one subConcept Di at a time and checks whether C is reachable from Di. If it is so, collects all the nodes in the cycle between C to C
  neighbours(Concept,Hier,SubClasses),
  check_and_collect_concepts(Concept,Hier,SubClasses,[],ConceptsToMerge).

check_and_collect_concepts(_Concept,_Hier,[],ListOfConcepts,ListOfConcepts):- !.

check_and_collect_concepts(Concept,Hier,[SubClass|OtherSubClasses],ConceptsToMerge0,ConceptsToMerge):-
  are_subClasses_int2(Concept,Hier,SubClass,ReachableFromSubClass),!,
  find_cycle_in_hier(Concept,Hier,ReachableFromSubClass,ConceptsToMerge1),
  append(ConceptsToMerge0,ConceptsToMerge1,ConceptsToMerge2),
  check_and_collect_concepts(Concept,Hier,OtherSubClasses,ConceptsToMerge2,ConceptsToMerge).

check_and_collect_concepts(Concept,Hier,[_SubClass|OtherSubClasses],ConceptsToMerge0,ConceptsToMerge):-
  % No cycle found for SubClass, continue with the search
  check_and_collect_concepts(Concept,Hier,OtherSubClasses,ConceptsToMerge0,ConceptsToMerge).


check_for_concepts_to_merge_test(Concept,Hier,ConceptsToMerge):- % Optimization in check_for_concepts_to_merge(Concept,Hier,ConceptsToMerge), work on first level of subclass from Concept. If from a direct subclass C is not reachable all the sons must not be checked. 
  reachable(Concept,Hier,ReachableFromSubClass),
  find_cycle_in_hier(Concept,Hier,ReachableFromSubClass,ConceptsToMerge).

find_cycle_in_hier(_Concept,_Hier,[],[]):- !.

find_cycle_in_hier(Concept,Hier,[ReachableFromSubClass|OtherReachable],[ReachableFromSubClass|ConceptsInCycle]):-
  are_subClasses_int2(Concept,Hier,ReachableFromSubClass),!,
  find_cycle_in_hier(Concept,Hier,OtherReachable,ConceptsInCycle).

find_cycle_in_hier(Concept,Hier,[_ReachableFromSubClass|OtherReachable],ConceptsInCycle):-
  % No cycle found for ReachableFromSubClass, continue with the search
  find_cycle_in_hier(Concept,Hier,OtherReachable,ConceptsInCycle).

are_subClasses_int2(C,Hier,C1,L):-  % similar to are_subClasses_int(KB,C,C1) -- To rename or unify with are_subClasses_int/3
  reachable(C1,Hier,L),
  %flatten(L0,L),
  memberchk(C,L),!.

are_subClasses_int2(C,_Hier,C):- !.

are_subClasses_int2(C,Hier,C1):-  % similar to are_subClasses_int(KB,C,C1) -- To rename or unify with are_subClasses_int/3
  reachable(C1,Hier,L),
  %flatten(L0,L),
  memberchk(C,L),!.
  

/*
merge_classes_int(TreeH0-NC-TreeD-Classes0,PC,PC1,TreeH-NC-TreeD-Classes):- % uno collegato all'altro direttamente
  edges(TreeH0,E),
  memberchk(PC1-PC,E),!,
  del_vertices(TreeH0,[PC],TreeH1), %rimuovo il nodo per C e unisco tutto in quello di C1
  update_edges(E,PC,PC1,EU),
  add_edges(TreeH1,EU,TreeH),
  C1=Classes0.PC1,
  del_dict(PC,Classes0,C,Classes1),
  merge_dict_value(C,C1,CM),
  Classes=Classes1.put(PC1,CM).
*/

merge_classes_int(KB0,PC,PC1,KB):- % not directly linked
  edges(KB0.hierarchy,E),
  collect_classes_2_merge(E,PC,PC1,PCL), % contains all the path from PC to PC1 (PC1 not included in the path)
  del_vertices(KB0.hierarchy,PCL,TreeH1),
  update_edges(E,PCL,PC1,EU),
  add_edges(TreeH1,EU,TreeH),
  Classes0=KB0.classes,
  C1=Classes0.PC1,
  del_classes_from_dict(PCL,KB0.classes,CL,Classes1),
  merge_dict_value(CL,C1,CM),
  Classes=Classes1.put(PC1,CM),
  KB=KB0.put([hierarchy=TreeH,classes=Classes]).

% contains all the path from PC to PC1 (PC1 not included in the path)
collect_classes_2_merge(E,PC,PC1,[PC]):-
  memberchk(PC-PC1,E),!.

collect_classes_2_merge(E,PC,PC1,[PC|PCT]):-
  member(PC-PCInt,E),
  collect_classes_2_merge(E,PCInt,PC1,PCT).

% change edges of odl node with new ones
update_edges([],_,_,[]):-!.

update_edges([PC-N|T],PCL,PC1,[PC1-N|TU]):-
  dif(N,PC1),
  memberchk(PC,PCL),!,
  update_edges(T,PCL,PC1,TU).

update_edges([N-PC|T],PCL,PC1,[N-PC1|TU]):-
  dif(N,PC1),
  memberchk(PC,PCL),!,
  update_edges(T,PCL,PC1,TU).

update_edges([_N0-_N1|T],PCL,PC1,TU):-
  update_edges(T,PCL,PC1,TU).

% deletes classes from dict creating a set of classes to be insertes in the merge node
del_classes_from_dict([],Classes,[],Classes):- !.

del_classes_from_dict([PC|TPC],Classes0,[C|TCL],Classes):-
  del_dict(PC,Classes0,C,Classes1),
  del_classes_from_dict(TPC,Classes1,TCL,Classes).

% joins two node in the dict
merge_dict_value(C,C1,CM):-
  is_list(C1),!,
  append(C,C1,CM0),
  flatten(CM0,CM).

merge_dict_value(C,C1,CM):-
  append(C,[C1],CM0),
  flatten(CM0,CM).

  
% adds one class, if Class already exists fails
add_class(KB0,Class,KB):-
  Classes0=KB0.classes,
  ClassesN=KB0.classesName,
  \+ _=Classes0.find(Class),
  NC0=KB0.nClasses,
  NC is NC0 + 1,
  Classes=Classes0.put(NC0,Class),
  add_edges(KB0.hierarchy,[0-NC0],TreeH), %% classe sotto owl:Thing
  add_subClass_expl(KB0.usermod,KB0.explanations,Class,'http://www.w3.org/2002/07/owl#Thing',Expls),
  KB=KB0.put([hierarchy=TreeH,nClasses=NC,classes=Classes,explanations=Expls,classesName=[Class|ClassesN]]).

% adds a list of classes
add_classes(H,[],H):- !.

add_classes(H0,[Ind|T],H):-
  add_class(H0,Ind,H1),!,
  add_classes(H1,T,H).

add_classes(H0,[_|T],H):-
  add_classes(H0,T,H).


% removes one class
/*  % TODO: if Class is in a list of equivalent classes, the class should be removed in the list (maybe also modifying the axiom), if the list becomes has a single class after removal -> modify node, if Class in not in a list modify the hierarcy by removing the links. Use explanations axiom to remove axioms from the KB.
remove_class(KB0,Class,KB):-
  Classes0=KB0.classes,
  ClassesN0=KB0.classesName,
  PC=Classes0.find(Class),
  NC0=KB0.nClasses,
  NC is NC0 - 1,
  Cs=Classes0.PC,
  (is_list(Cs) ->
    (
      delete(Cs,
  del_dict(PC,Classes0,_,Classes),
  delete(ClassesN0,Class,ClassesN),
  add_edges(KB0.hierarchy,[0-NC0],TreeH), %% classe sotto owl:Thing
  add_subClass_expl(KB0.usermod,KB0.explanations,Class,'http://www.w3.org/2002/07/owl#Thing',Expls),
  KB=KB0.put([hierarchy=TreeH,nClasses=NC,classes=Classes,explanations=Expls,classesName=[Class|ClassesN]]).
*/

% Removes a list of classes
remove_classes(H,[],H):- !.

remove_classes(H0,[Ind|T],H):-
  remove_class(H0,Ind,H1),!,
  remove_classes(H1,T,H).

remove_classes(H0,[_|T],H):-
  remove_classes(H0,T,H).


% Adds an individual, if already exists fails
add_individual(KB0,Ind,KB):-
  Inds0=KB0.individuals,
  \+ member(Ind,Inds0),
  NI0=KB0.nIndividuals,
  NI is NI0 + 1,
  KB=KB0.put([nIndividuals=NI,individuals=[Ind|Inds0]]).

% Adds a list of individuals
add_individuals(H,[],H):- !.

add_individuals(H0,[Class|T],H):-
  add_individual(H0,Class,H1),!,
  add_individuals(H1,T,H).

add_individuals(H0,[_|T],H):-
  add_individuals(H0,T,H).

add_annotationProperty(KB0,Ind,KB):-
  Inds0=KB0.annotationProperties,
  \+ member(Ind,Inds0),
  KB=KB0.put(annotationProperties,[Ind|Inds0]).

% Adds a lis of annotationProperties
add_annotationProperties(H,[],H):- !.

add_annotationProperties(H0,[Class|T],H):-
  add_annotationProperty(H0,Class,H1),!,
  add_annotationProperties(H1,T,H).

add_annotationProperties(H0,[_|T],H):-
  add_annotationProperties(H0,T,H).

add_dataProperty(KB0,Ind,KB):-
  Inds0=KB0.dataProperties,
  \+ member(Ind,Inds0),
  KB=KB0.put(dataProperties,[Ind|Inds0]).

% Adds a lis of dataProperties
add_dataProperties(H,[],H):- !.

add_dataProperties(H0,[Class|T],H):-
  add_dataProperty(H0,Class,H1),!,
  add_dataProperties(H1,T,H).

add_dataProperties(H0,[_|T],H):-
  add_dataProperties(H0,T,H).

add_datatype(KB0,Ind,KB):-
  Inds0=KB0.datatypes,
  \+ member(Ind,Inds0),
  KB=KB0.put(datatypes,[Ind|Inds0]).

% Adds a lis of datatypes
add_datatypes(H,[],H):- !.

add_datatypes(H0,[Class|T],H):-
  add_datatype(H0,Class,H1),!,
  add_datatypes(H1,T,H).

add_datatypes(H0,[_|T],H):-
  add_datatypes(H0,T,H).

add_objectProperty(KB0,Ind,KB):-
  Inds0=KB0.objectProperties,
  \+ member(Ind,Inds0),
  KB=KB0.put(objectProperties,[Ind|Inds0]).

% Adds a lis of objectProperties
add_objectProperties(H,[],H):- !.

add_objectProperties(H0,[Class|T],H):-
  add_objectProperty(H0,Class,H1),!,
  add_objectProperties(H1,T,H).

add_objectProperties(H0,[_|T],H):-
  add_objectProperties(H0,T,H).

% Adds all equivalentClasses axioms
add_all_equivalentClasses(H0,M,H):-
  findall(CL,M:equivalentClasses(CL),L),
  add_all_equivalentClasses_1(H0,L,H).

add_all_equivalentClasses_1(H,[],H).

add_all_equivalentClasses_1(H0,[ClassList|T],H):-
  add_equivalentClasses(H0,ClassList,H1),
  add_all_equivalentClasses_1(H1,T,H).

% Adds a set of equivalent classes, if there exists a set containing some of the classes the two set are merged, otherwise the new set is added. Fails whether there exists a node with all the classes contained in the new set
add_equivalentClasses(H0,ClassList,H):-
  add_eqClass_hier(H0,ClassList,H1),
  add_subClasses_expl(H1,ClassList,H2),
  add_eqClass_expl(H2,equivalentClasses(ClassList),H).

add_eqClass_hier(KB0,ClassList0,KB):-
  sort(ClassList0,ClassList),
  Classes0=KB0.classes,
  findall(NodeC,(member(OneOfClassList,ClassList),NodeC=Classes0.find(OneOfClassList)),Nodes),
  (length(Nodes,1) -> %% if there is already a node, modify only the node in dict
    (Nodes=[Node],
     update_eqNode(KB0,Node,ClassList,KB)
    )
   ;
    (Nodes=[PC1|PCL],!, %% there are more nodes -> merge
     edges(KB0.hierarchy,E),
     del_vertices(KB0.hierarchy,PCL,TreeH1),
     update_edges(E,PCL,PC1,EU),
     add_edges(TreeH1,EU,TreeH),
     Classes0=KB0.classes,
     C1=Classes0.PC1,
     del_classes_from_dict(PCL,KB0.classes,CL,Classes1),
     merge_dict_value(CL,C1,CM),
     Classes=Classes1.put(PC1,CM),
     KB=KB0.put([hierarchy=TreeH,classes=Classes])
    )
  ).

update_eqNode(KB0,Node,ClassList,KB):-
  Classes0=KB0.classes,
  EqClasses=Classes0.get(Node),
  ( is_list(EqClasses) -> EqClassesList = EqClasses ; EqClassesList = [EqClasses]),
  ( dif(EqClassesList,ClassList) ->
    ( append(EqClassesList,ClassList,UnsortedClassList),
      sort(UnsortedClassList,ClassSet),
      Classes=Classes0.put(Node,ClassSet),
      KB=KB0.put(classes,Classes)
    )
   ;
    fail
  ).

add_eqClass_hier(KB0,ClassList,KB):-  %% if there is not a node it is added. NOTE: adding classes must be done BEFORE managing subclass axioms
  NC0=KB0.nClasses,
  NC is NC0 + 1,
  Classes0=KB0.classes,
  Classes=Classes0.put(NC0,ClassList),
  add_edges(KB0.hierarchy,[0-NC0],TreeH),
  KB=KB0.put([hierarchy=TreeH,nClasses=NC,classes=Classes]).

add_subClasses_expl(KB,[],KB):-!.

add_subClasses_expl(KB0,[Class|List],KB):-
  add_subClass_expl(KB0.usermod,KB0.explanations,Class,'http://www.w3.org/2002/07/owl#Thing',Expls1),
  KB1=KB0.put(explanations,Expls1),
  add_subClasses_expl(KB1,List,KB).


add_eqClass_expl(KB0,Ax,KB):-
  add_eqClass_simple_expl(KB0,Ax,KB).%1),
%  add_eqClass_complex_expl(H1,Ax,H).
  
/*
add_eqClass_expl(KB0,ClassList,ClassList,KB):-
  add_eqClass_simple_expl(KB0,ClassList,ClassList,equivalentClasses(ClassList),KB1),
  add_eqClass_complex_expl(KB1,equivalentClasses(ClassList),KB).
*/

% Adds explanations for every class in the set of equivalent classes
add_eqClass_simple_expl(KB0,equivalentClasses(ClassList),KB):-
  add_eqClass_simple_expl(KB0.usermod,KB0.explanations,ClassList,ClassList,equivalentClasses(ClassList),Expls),
  KB=KB0.put(explanations,Expls).

add_eqClass_simple_expl(KB0,disjointUnion(Class,DisjList),KB):-
  add_eqClass_simple_expl(KB0.usermod,KB0.explanations,[Class,unionOf(DisjList)],[Class,unionOf(DisjList)],disjointUnion(Class,DisjList),Expls),
  KB=KB0.put(explanations,Expls).

add_eqClass_simple_expl(_M,Expls,[],_L,_Ax,Expls):- !.

add_eqClass_simple_expl(M,Expls0,[C|T],L,Ax,Expls):-
  add_eqClass_simple_expl(M,Expls0,C,T,L,Ax,Expls1),
  add_eqClass_simple_expl(M,Expls1,T,L,Ax,Expls).

add_eqClass_simple_expl(_M,E,_C,[],_L,_Ax,E):- !.

add_eqClass_simple_expl(M,E0,C,[C|T],L,Ax,E):- !,
  add_eqClass_simple_expl(M,E0,C,T,L,Ax,E).

add_eqClass_simple_expl(M,E0,C,[C1|T],L,Ax,E):-
  trill:hier_ax2ex(M,Ax,ExAx),
  ( member(ex(C,C1)-Ex,E0) ->
     ( member(ex(C1,C)-ExC,E0),
       delete(E0,ex(C,C1)-Ex,E1),
       delete(E1,ex(C1,C)-ExC,E2),
       trill:hier_or_f(M,ExAx,Ex,ExOr),
       trill:hier_or_f(M,ExAx,ExC,ExCOr),
       add_eqClass_simple_expl(M,[ex(C,C1)-ExOr,ex(C1,C)-ExCOr|E2],C,T,L,Ax,E)
     )
    ;
     add_eqClass_simple_expl(M,[ex(C,C1)-ExAx,ex(C1,C)-ExAx|E0],C,T,L,Ax,E)
  ).

% Combines explanations for all members of the equivalent axiom
add_eqClass_complex_expl(KB0,equivalentClasses(ClassList),KB):-
  member(C,ClassList),!, % prendo una classe a caso
  Classes0=KB0.classes,
  PC=Classes0.find(C),
  combine_eqClass_expl(KB0.usermod,KB0.explanations,Classes0.PC,Expls),
  KB=KB0.put(explanations.Expls).

add_eqClass_complex_expl(KB0,disjointUnion(Class,_ClassList),KB):-
  Classes0=KB0.classes,
  PC=Classes0.find(Class),
  combine_eqClass_expl(KB0.usermod,KB0.explanations,Classes0.PC,Expls),
  KB=KB0.put(explanations.Expls).

combine_eqClass_expl(_M,E,[],E):- !.

combine_eqClass_expl(M,Expls0,[C|T],Expls):-
  combine_eqClass_expl(M,Expls0,C,T,Expls1),
  combine_eqClass_expl(M,Expls1,T,Expls).

combine_eqClass_expl(_M,Expls0,_C,[],Expls):- !,
  sort(Expls0,Expls).

combine_eqClass_expl(M,Expls0,C,[C1|T],Expls):-
  %abolish_table_subgoals(expl_combination(_,_,_,_,_,_)),
  findall(Ex,expl_combination(M,Expls0,C,C1,[],Ex),Exs0),
  combine_all(M,Exs0,Exs),
  ( member(ex(C,C1)-Exs0,Expls0) ->
     ( member(ex(C1,C)-Exs0C,Expls0),
       delete(Expls0,ex(C,C1)-Exs0,Expls1),
       delete(Expls1,ex(C1,C)-Exs0C,Expls2),
       combine_eqClass_expl(M,[ex(C,C1)-Exs,ex(C1,C)-Exs|Expls2],C,T,Expls)
     )
    ;
     combine_eqClass_expl(M,[ex(C,C1)-Exs,ex(C1,C)-Exs|Expls0],C,T,Expls)
  ).

expl_combination(_M,Expls,C,C1,Used,Ex):-
  member(ex(C,C1)-Ex0,Expls),
  \+ (memberchk(C,Used), memberchk(C1,Used)),
  member(Ex,Ex0).

expl_combination(M,Expls,C,C1,Used,Ex):-
  member(ex(C,C0)-Ex0,Expls),
  dif(C0,C1),dif(C0,'http://www.w3.org/2002/07/owl#Thing'),
  \+ (memberchk(C,Used), memberchk(C0,Used)),
  member(Ex01,Ex0),
  expl_combination(M,Expls,C0,C1,[C,C0|Used],Ex1),
  trill:hier_and_f(M,Ex01,Ex1,Ex).

combine_all(M,[],Ex):-
  trill:hier_empty_expl(M,Ex).

combine_all(M,[H|T],Ex):-
  combine_all(M,T,Ex0),
  trill:hier_or_f(M,Ex0,H,Ex).


% Adds all disjointClasses axioms
add_all_disjointClasses(H0,M,H):-
  findall(CL,M:disjointClasses(CL),L),
  add_all_disjointClasses_1(H0,L,H).

add_all_disjointClasses_1(H,[],H).

add_all_disjointClasses_1(H0,[ClassList|T],H):-
  add_disjointClasses(H0,ClassList,H1),
  add_all_disjointClasses_1(H1,T,H).


%% add_disjountClasses(...) adds classes and verifies whether there is not a contraddiction. Fails in case of contradiction
add_disjointClasses(KB0,ClassList,KB):-
  add_disjClass_hier(KB0,ClassList,KB).
  %add_disjClass_expl(KB1,disjointClasses(ClassList),KB).
  
add_disjClass_hier(KB0,ClassList,KB):-
  %add_classes(KB0,ClassList,KB1),
  add_single_disjointClass(KB0,ClassList,KB).

add_single_disjointClass(KB,[],KB):- !.

add_single_disjointClass(KB0,[C|T],KB):-
  add_single_disjointClass_int(KB0,C,T,KB1),
  add_single_disjointClass(KB1,T,KB).


add_single_disjointClass_int(KB,_C,[],KB):- !.

add_single_disjointClass_int(KB0,C,[C|T],KB):- !,
  add_single_disjointClass_int(KB0,C,T,KB).

add_single_disjointClass_int(KB0,C,[C1|T],KB):-
  ( add_disjoint_link(KB0,C,C1,KB1) ->
     add_single_disjointClass_int(KB1,C,T,KB)
    ;
     fail
  ).

add_disjClass_expl(KB0,Ax,KB):-
  (Ax=..[disjointClasses,Arg] ; Ax=..[disjointUnion,_,Arg]),
  add_disjClass_expl(KB0.usermod,KB0.explanations,Arg,Ax,Expls),
  KB=KB0.put(explanations,Expls).

add_disjClass_expl(_M,Expls,[],_Ax,Expls):- !.

add_disjClass_expl(M,Expls0,[C|T],Ax,Expls):-
  add_disjClass_expl(M,Expls0,C,T,Ax,Expls1),
  add_disjClass_expl(M,Expls1,T,Ax,Expls).

add_disjClass_expl(_M,E,_C,[],_Ax,E):- !.

add_disjClass_expl(M,E0,C,[C|T],Ax,E):- !,
  add_disjClass_expl(M,E0,C,T,Ax,E).

add_disjClass_expl(M,E0,C,[C1|T],Ax,E):-
  trill:hier_ax2ex(M,Ax,ExAx),
  ( member(dis(C,C1)-Ex,E0) ->
      ( delete(E0,dis(C,C1)-Ex,E1),
        trill:hier_or_f(M,ExAx,Ex,ExOr),
        add_disjClass_expl(M,[dis(C,C1)-ExOr|E1],C,T,Ax,E)
      )
    ;
      add_disjClass_expl(M,[dis(C,C1)-ExAx|E0],C,T,Ax,E)
  ).


% Adds all disjointUnion axioms
add_all_disjointUnion(H0,M,H):-
  findall(C-D,M:disjointUnion(C,D),L),
  add_all_disjointUnion_1(H0,L,H).

add_all_disjointUnion_1(H,[],H).

add_all_disjointUnion_1(H0,[C-D|T],H):-
  add_disjointUnion(H0,C,D,H1),
  add_all_disjointUnion_1(H1,T,H).

%% add_disjointUnion(classExpression,set(classExpression)) TODO: check it works properly and add classes from axiom. TRILL must handle these axioms.
add_disjointUnion(KB0,Class,DisjointUnion,KB):-
  add_eqClass_hier(KB0,[Class,unionOf(DisjointUnion)],KB1),
  add_disjClass_hier(KB1,DisjointUnion,KB2),
  add_eqClass_expl(KB2,disjointUnion(Class,DisjointUnion),KB).
  %add_disjClass_expl(KB3,disjointUnion(Class,DisjointUnion),KB).


% Adds all subClassOf axioms
add_all_subClassOf(H0,M,H):-
  findall(C-D,M:subClassOf(C,D),L),
  add_all_subClassOf_1(H0,L,H).

add_all_subClassOf_1(H,[],H).

add_all_subClassOf_1(H0,[C-D|T],H):-
  add_subClassOf(H0,C,D,H1),
  add_all_subClassOf_1(H1,T,H).

%% add_subClassOf(...)  adds/modifies the edge, checking first that the two classes are not equivalent. One or both classes may be not present
add_subClassOf(KB0,SubClass,SupClass,KB):-
  %add_classes(KB0,[SubClass,SupClass],KB1),
  add_hierarchy_link(KB0,SubClass,SupClass,KB),!.

add_subClass_expl(M,Expls0,C,C1,[ex(C,C1)-ExF|Expls]):-
  member(ex(C,C1)-Ex,Expls0),!,
  delete(Expls0,ex(C,C1)-Ex,Expls),
  trill:hier_ax2ex(M,subClassOf(C,C1),ExAx),
  trill:hier_or_f(M,ExAx,Ex,ExF).

add_subClass_expl(M,Expls,C,C1,[ex(C,C1)-ExAx|Expls]):-
  trill:hier_ax2ex(M,subClassOf(C,C1),ExAx).

add_subClass_expl(M,Expls0,C,C1,Expl,[ex(C,C1)-ExF|Expls]):-
  member(ex(C,C1)-Ex,Expls0),!,
  delete(Expls0,ex(C,C1)-Ex,Expls),
  trill:hier_or_f(M,Expl,Ex,ExF).

add_subClass_expl(_M,Expls,C,C1,Expl,[ex(C,C1)-Expl|Expls]).

/*
 Return the explanation of C subClassOf D
*/
get_subClass_expl(_M,Expls,C,D,Expl):-
  member(ex(C,D)-Expl,Expls).

/*
 Takes a class in Class and returns the set of classes with explanations that are connected with CLass in the hierarchy
*/
get_hierarchy(M:Class,H4C):-
  M:kb_hierarchy(KB),
  Classes=KB.classes,
  Pos=Classes.find(Class),
  edges(KB.hierarchy,E),
  get_combined_expls(KB.usermod,Class,Pos,E,Classes,KB.explanations,MH4C), MH4C = (_M,H4C).

/*
 Takes the KB descriptor and a class in Class, and returns the set of classes with explanations that are connected with Class in the hierarchy
*/
get_hierarchy(KB,Class,H4C):- %prende la gerarchia (KB) una classe e la spiegazione per arrivare a quella classe e resituisce l'insieme di tutte le classi con spiegazioni da quella in su
  Classes=KB.classes,
  Pos=Classes.find(Class),%gtrace,
  edges(KB.hierarchy,E),
  get_combined_expls(KB.usermod,Class,Pos,E,Classes,KB.explanations,MH4C), MH4C = (_M,H4C).

get_combined_expls(M,Class,Pos,E,Classes,Expls,(M,H4C)):-
  get_single_expls(M,Class,Pos,E,Classes,Expls,[Class],H4C).

append_expl((M,AllExpl),(M,[EndClass-NewExpl]),(M,NewAllExpl)):-
  \+ memberchk(EndClass-_,AllExpl),!,
  append(AllExpl,[EndClass-NewExpl],NewAllExpl).

append_expl((M,AllExpl),(M,[EndClass-NewExpl]),(M,NewAllExpl)):-gtrace,
  member(EndClass-OldExpl,AllExpl),%gtrace,
  delete(AllExpl,EndClass-OldExpl,AllExpl0),
  trill:hier_or_f_check(M,OldExpl,NewExpl,NewExplT),%gtrace,
  append(AllExpl0,[EndClass-NewExplT],NewAllExpl).


get_next(P,_E,Classes,P,NextClass):-
  EqClasses=Classes.P,
  is_list(EqClasses),
  member(NextClass,EqClasses).

get_next(P,E,Classes,NextP,NextClass):-
  member(NextP-P,E),
  \+ owl_f(NextP),
  NextClass=Classes.NextP,
  \+ is_list(NextClass).

get_next(P,E,Classes,NextP,NextClass):-
  member(NextP-P,E),
  \+ owl_f(NextP),
  EqClasses=Classes.NextP,
  is_list(EqClasses),
  member(NextClass,EqClasses).

get_single_expls(_M,Class,P,E,Classes,Expls,Used,[NextClass-Expls4Class]):-
  get_next(P,E,Classes,_NextP,NextClass),
  \+ member(NextClass,Used),
  member(ex(Class,NextClass)-Expls4Class,Expls).

get_single_expls(M,Class,P,E,Classes,Expls,Used,[EndClass-TotExpl]):-
  get_next(P,E,Classes,NextP,NextClass),
  \+ member(NextClass,Used),
  member(ex(Class,NextClass)-Expls4Class,Expls),
  get_single_expls(M,NextClass,NextP,E,Classes,Expls,[NextClass|Used],[EndClass-Expls4EndClass]),
  trill:hier_and_f(M,Expls4Class,Expls4EndClass,TotExpl).%,
%  sort(TotExpl0,TotExpl),
%  length(TotExpl0,LTE),
%  length(TotExpl,LTE).


/*
get_single_expls(Class,P,E,Classes,Expls,Start,[NextClass-[[equivalentClasses(ListExpls4Class)]]]):-
  get_next(P,E,Classes,P,NextClass),
  dif(NextClass,Start),
  member(ex(NextClass,Class)-Exs,Expls),
  member([equivalentClasses(ListExpls4Class)],Exs).

get_single_expls(Class,P,E,Classes,Expls,Start,[EndClass-[TotExpl]]):-
  get_next(P,E,Classes,P,NextClass),
  dif(NextClass,Start),
  member(ex(NextClass,Class)-Exs,Expls),
  member([equivalentClasses(ListExpls4Class)],Exs),
  get_single_expls(NextClass,P,E,Classes,Expls,Start,[EndClass-[Expl4EndClass]]),
  append([equivalentClasses(ListExpls4Class)],Expl4EndClass,TotExpl).
*/

/*
get_one_expl(M,Pos,Class,E,Classes,Expls,Expl4Class,EndClass-H4C):-
  get_hierarchy_ric(M,Pos,Class,E,Classes,Expls,EndClass-Expl),
  trill:hier_and_f(M,Expl4Class,Expl,H4C).

get_hierarchy_ric(M,0,_C,_E,_Classes,_Expls,0-Expl):- % arrivato a owl:Thing
  trill:hier_empty_expl(M,Expl).

get_hierarchy_ric(M,n,_C,_E,_Classes,_Expls,n-Expl):- % arrivato a owl:Nothing
  trill:hier_empty_expl(M,Expl).

get_hierarchy_ric(M,P,Class,E,Classes,Expls,EndClass-Expl):-
  EqClasses=Classes.P,
  is_list(EqClasses),
  member(NextClass,EqClasses),
  member(ex(Class,NextClass)-Exs,Expls),
  member(Ex0,Exs),
  get_hierarchy_ric(M,P,NextClass,E,Classes,Expls,EndClass-Ex1),
  trill:hier_and_f(M,Ex0,Ex1,Expl).

get_hierarchy_ric(M,P,Class,E,Classes,Expls,EndClass-Expl):-
  member(NextP-P,E),
  (owl_f(NextP) -> 
    ( Expl = [], EndClass = Class)
   ;
    ( NextClass=Classes.NextP,
      member(ex(Class,NextClass)-Exs,Expls),
      member(Ex0,Exs),
      get_hierarchy_ric(M,NextP,NextClass,E,Classes,Expls,EndClass-Ex1),
      trill:hier_and_f(M,Ex0,Ex1,Expl)
    )
  ).
*/


% Adds all complex subClassOf relations
add_all_complex_subClassOf(H,[],H).

add_all_complex_subClassOf(H0,[C-D-Ex|T],H):-
  add_complex_subClassOf(H0,C,D,Ex,H1),
  add_all_complex_subClassOf(H1,T,H).

%% add_complex_subClassOf(...)  adds/modifies the edge, checking first that the two classes are not equivalent. One or both classes may be not present
add_complex_subClassOf(KB0,SubClass,SupClass,Expl,KB):-
  add_classes(KB0,[SubClass,SupClass],KB1),
  add_hierarchy_link(KB1,SubClass,SupClass,Expl,KB),!.



complex_subClassOf(M,Classes,C,D,Expl):-
  member(C,Classes),
  trill:find_sub_sup_class(M,C,D,Ax),
  trill:hier_ax2ex(M,Ax,Expl).

complex_subClassOf(M,Classes,complementOf(C),D,Expl):-
  member(complementOf(C),Classes),
  trill:find_neg_class(C,D),
  trill:hier_ax2ex(M,equivalentClasses([complementOf(C),D]),Expl).

%complex_subClassOf(M,Classes,intersectionOf(Cs),D,Expl):-
%  member(intersectionOf(Cs),Classes),
%  member(D,Cs),
%  trill:hier_initial_expl(M,Expl).

% owl fixed classes (owl:Thing e owl:Nothing)
owl_f(0).
owl_f(n).


update_hierarchy(M:Axiom) :-
  update_hierarchy(M,Axiom).

update_hierarchy(_M,_Axiom).



remove_subClassOf(M,C,D):-
  M:kb_hierarchy(KB0),
  remove_subClassOf(KB0,C,D,KB),
  retractall(M:kb_hierarchy(_)),
  assert(M:kb_hierarchy(KB)).

/*
%% remove_subClassOf(...)  deletes/modifies the edge, checking first that the two classes are not equivalent. One or both classes may be not present
remove_subClassOf(KB0,C,D,KB):-
  Classes0=KB0.classes,
  PC=Classes0.find(C),
  PD=Classes0.find(D),!,
  (dif(PC,PD) ->
     ( remove_hierarchy_link_int1(KB0,PC,PD,C,D,KB) )
    ;
     ( % remove_hierarchy_link_int2(KB0,PC,C,D,KB) % TODO: modify ex(C,D) with sub(C,D) and eq(C,D). 
       true
     )
  ),!.


remove_hierarchy_link_int1(KB0,PC,PD,C,D,KB):- % different nodes
 Expls0=KB0.explanations,
 member(ex(C,D)-Ex0,Expls0),
 delete(Expls0,ex(C,D)-Ex0,Expls1),
 ( trill:is_or_f(Ex0) -> 
     ( trill:hier_ax2ex(M,subClassOf(C,D),ExAx),
       trill:remove_or(Ex0,ExAx,Ex),
       append([ex(C,D)-Ex],Expls1,Expls),
       KB=KB0.put([explanations=Expls,hierarchy=TreeH])
     )
    ;
     ( del_edges(KB0.hierarchy,[PD-PC],TreeH1),
       add_edges(TreeH1,[0-PC],TreeH),
       KB=KB0.put([explanations=Expls1,hierarchy=TreeH])
     )
  ).
  
remove_hierarchy_link_int2(KB0,PC,C,D,KB):- % same node
 Expls0=KB0.explanations,
 member(ex(C,D)-Ex0,Expls0),
 delete(Expls0,ex(C,D)-Ex0,Expls1),
 ( trill:is_or_f(Ex0) -> 
     ( trill:hier_ax2ex(M,subClassOf(C,D),ExAx),  % equivalentClasses axioms link C and D, only the explanation subClassOf(C,D) must be removed
       trill:remove_or(Ex0,ExAx,Ex),
       append([ex(C,D)-Ex],Expls1,Expls),
       KB=KB0.put([explanations=Expls,hierarchy=TreeH])
     )
    ;
     ( del_edges(KB0.hierarchy,[PD-PC],TreeH1),  % a cycle of subClassOf axioms creates a nod of equivalent classes, open the cycle.
       add_edges(TreeH1,[0-PC],TreeH),
       KB=KB0.put([explanations=Expls1,hierarchy=TreeH])
     )
  ).
 */
 
